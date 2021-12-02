class CsvImportWorker < BaseWorker
  sidekiq_options lock: :until_executed, unique_across_queues: true

  def perform(csv_import_id)
    csv_import = CsvImport.find(csv_import_id)
    return if csv_import.completed_at || !csv_import.wallet
    csv_import.process
    return if csv_import.failed?

    csv_import.ready_for_import
    csv_import.import_file
    if csv_import.success_count && csv_import.success_count > 0
      UpdateUserStatsWorker.perform_later(csv_import.user_id)
    end
  end
end
