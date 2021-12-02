class Report < ApplicationRecord
  FONT_COLOR = '1f4a64'.freeze

  include CsvAttachment
  belongs_to :user

  before_validation :set_dates_from_year
  validates_presence_of :type, :year, :from, :to, :format
  validate :ensure_from_is_less_than_to
  validate :ensure_format_is_valid

  before_create -> { self.name = default_name if name.blank? }
  after_create_commit :enqueue_report_job

  has_csv_attachment :file, base: 'reports', additional_types: ['application/pdf', 'application/vnd.Mobius.TXF'], validate_media_type: false

  def generated?
    !!generated_at
  end

  def generate_and_save!
    rows = prepare_report(generate)
    data = send("to_#{format}", rows)
    return touch(:generated_at) unless data

    data = data.is_a?(StringIO) ? data : StringIO.new(data)
    ext = format.to_s
    ext = 'xlsx' if ext == 'xls'
    data.original_filename = aws_file_name(format, ext)
    self.generated_at = Time.now
    self.file = data
    save!
  end

  def supported_formats
    [:csv, :xls]
  end

  # this should only return the raw data
  def generate
    raise "override this"
  end

  # this should return an array that will go straight into a csv/excel files (also include the headers)
  def prepare_report(data)
    data
  end

  private

  def to_csv(rows)
    CSV.generate do |csv|
      rows.each { |row| csv << row }
    end
  end

  def to_xls(rows)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(:name => "Sheet") do |sheet|
      rows.each { |row| sheet.add_row row }
    end
    package.to_stream
  end

  def to_pdf(rows)
    raise 'not implemented'
  end

  def setup_report
    @current_page = 1
    @report_temp_dir = Dir.mktmpdir( "report_#{user_id}_#{Time.now.to_i}")
  end

  def combine_pages
    tempfile = Tempfile.new
    final_document = CombinePDF.new
    Dir.children(@report_temp_dir).sort.each do |page|
      final_document << CombinePDF.load(File.join(@report_temp_dir, page))
    end
    final_document.save(tempfile.path)
    tempfile.read
  end

  def set_dates_from_year
    if year && year.to_i > 2000 && year.to_i < 3000
      self.from, self.to = user.year_start_end_dates(year.to_i)
    end
  end

  def ensure_from_is_less_than_to
    return unless from && to
    errors.add(:from, 'must be less than to') if from > to
  end

  def ensure_format_is_valid
    unless supported_formats.map(&:to_s).include?(format.to_s)
      errors.add(:format, "must be one of: #{supported_formats.join(', ')}")
    end
  end

  def aws_file_name(format, ext)
    [
      'cryptoapp',
      year,
      name.squish.gsub(' ', '_').gsub(/\W/, '').downcase,
      user_id.to_s + SecureRandom.base58.first(8),
      created_at.to_i,
      (ext == format.to_s ? nil : format)
    ].compact.map(&:to_s).join('_') + '.' + ext
  end

  def default_name
    self.class.name.titlecase
  end

  def analytics
    @analytics ||= TaxAnalytics.new(user, year: year, from: from, to: to)
  end

  def enqueue_report_job
    ReportGeneratorWorker.perform_later(id)
  end

  def display_date(date, fmt=nil)
    return unless date&.present?
    date = date.to_s
    fmt ||= "%m/%d/%Y %H:%M" if user.country.code == 'USA'
    fmt ||= "%d/%m/%Y %H:%M"
    DateTime.parse(date).in_time_zone(user.timezone || user.country.timezone || 'UTC').strftime(fmt)
  end

  def display_base(amount, symbol=true)
    mon = Money.new((amount.to_d * 100).to_i, user.base_currency.symbol)
    if symbol
      mon.format
    else
      mon.format(symbol: '')
    end
  end

  def display_crypto(amount)
    '%.8f' % amount
  end

  # works with the following formats:
  # $12,000.25 USD
  # ($12,000.25)
  def to_dec(number)
    number = number.to_s unless number.is_a?(String)
    neg = number.include?('-') || (number.include?('(') && number.include?(')'))
    number = number.gsub(/[^0-9.]/, '') # removes everything apart from digits and decimal (dont mutate the string! with gsub!)
    number = "-" + number if neg
    number.to_d
  end

  def sum_row(array, col)
    array.sum do |row|
      if row && row[col]
        to_dec(row[col])
      else
        0
      end
    end
  end

  def pdf?
    format == 'pdf'
  end
end
