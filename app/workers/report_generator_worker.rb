class ReportGeneratorWorker < BaseWorker
  sidekiq_options lock: :until_executed, unique_across_queues: true

  def perform(report_id)
    report = Report.find report_id
    report.generate_and_save! unless report.generated?
  end
end
