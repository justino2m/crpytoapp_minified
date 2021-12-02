class CsvImport < ApplicationRecord
  include CsvAttachment
  include CsvProcessor

  FAILED_STATES = [:processing_failed, :failed]
  MANUAL_STATES = [:enter_mapping_id, :enter_required_options]
  PROCESSABLE_STATES = [:pending, :ready]

  belongs_to :user
  belongs_to :wallet
  has_csv_attachment :file, presence: true
  validate :validate_options
  serialize :initial_rows, Array
  serialize :results, HashSerializer
  serialize :options, HashSerializer
  store_accessor :options, :timezone, :file_col_sep, :file_row_sep, :currency_id, :withdrawal_label, :deposit_label
  store_accessor :results, :success_count, :error_count, :skipped_count, :duplicate_count, :total_count, :bad_rows
  before_update :update_state_manually, if: -> { state_name.in?(MANUAL_STATES) }

  after_commit :schedule_job, on: [:create, :update], if: -> do
    state_name.in?(PROCESSABLE_STATES)
  end

  state_machine :state, initial: :pending do
    after_transition to: :processing, do: :prepare_and_set_file
    after_transition to: [:completed, :failed], do: :report_to_jira

    # this can prevent state from transitioning to 'failed' if PG::InFailedSqlTransaction gets raised
    # so we call it explicitly in the worker
    # after_transition to: :importing, do: :import_file

    event :process do
      transition pending: :processing
    end

    event :update_state_manually do
      transition enter_mapping_id: :enter_required_options, if: :required_options_missing?
      transition [:enter_mapping_id, :enter_required_options] => :ready, if: :ready_to_go?
    end

    event :ready_for_import do
      transition processing: :enter_mapping_id, if: :multiple_mapping_ids?
      transition processing: :enter_required_options, if: :required_options_missing?
      transition processing: :unknown_csv, if: :mapping_id_missing?
      transition [:processing, :ready] => :importing
    end

    event :complete do
      transition importing: :completed
    end

    event :failed do
      transition processing: :processing_failed
      transition importing: :failed
    end
  end

  # returns hash of mapping id to mapping class
  #   "etoro-txns" => EtoroMapper
  def self.all_mappers
    @mappers ||=
      Dir.glob(File.expand_path("app/csv_mappers/*.rb", Rails.root))
        .select { |path| path.end_with?('_mapper.rb') }
        .map { |path| path.split('/').last.gsub('.rb', '').camelize.constantize }
        .inject({}) do |memo, klass|
        klass&.mappings&.each do |mapping|
          if memo[mapping[:id]]
            raise "duplicate mapping id found: #{mapping[:id]}"
          else
            memo[mapping[:id]] = klass.to_s
          end
        end
        memo
      end
  end

  # returns hash of mapping ids and their scores with highest scores on top
  #   "etoro-txns" => 2
  #   "blitz-txns" => 1
  def potential_mappers
    @potential_mappers ||= Hash[self.class.all_mappers.inject({}) do |memo, (mapping_id, klass)|
      klass = klass.constantize
      mapping = klass.mappings.find { |x| x[:id] == mapping_id }
      score = klass.confidence_score(initial_rows, file_file_name, mapping, wallet) || 0
      memo[mapping_id] = score unless score.zero?
      memo
    end.sort_by { |_, v| -v }]
  end

  def failed?
    state_name.in?(FAILED_STATES)
  end

  def completed?
    state?(:completed)
  end

  def fail!(message)
    self.error = message
    failed
  end

  def required_options
    mapper&.mapping&.dig(:required_options)&.map(&:to_s) || []
  end

  def import_file
    return unless state?(:importing)
    return fail!(mapper.mapping[:error]) if mapper.mapping[:error].present?
    self.results, @exception, exception_message = mapper.import(Paperclip.io_adapters.for(file), file_file_name, file_col_sep || ',', file_row_sep || 'auto')
    self.completed_at = Time.now
    if @exception
      fail!("Internal error occured, code: #{exception_message}")
    else
      complete
    end
  end

  def request_assistance(message)
    # JiraWorker.perform_later(id, true, message) if message.present?
  end

  private

  def validate_options
    if timezone.present? && !TZInfo::Timezone.all_identifiers.include?(timezone)
      errors.add(:timezone, 'is invalid')
    end
  end

  def mapping_id_missing?
    mapping_id.nil?
  end

  def multiple_mapping_ids?
    mapping_id.nil? && potential_mappers.count > 1
  end

  def required_options_missing?
    (required_options - options.keys).any?
  end

  def ready_to_go?
    mapping_id.present? && !multiple_mapping_ids? && !required_options_missing?
  end

  def mapper
    return unless mapping_id
    @mapper ||= begin
      klass = self.class.all_mappers[mapping_id]
      raise "csv import failed - no klass found for mapping id: #{mapping_id}" unless klass
      klass.constantize.new(user, wallet, mapping_id, options)
    end
  end

  def schedule_job
    CsvImportWorker.perform_later(id)
  end

  def report_to_jira
    # delay the job else it gets executed before we have saved the record due to after_transition
    # JiraWorker.perform_in(10.seconds, id, false, @exception&.message&.first(200), @exception&.backtrace&.take(20))
  end
end
