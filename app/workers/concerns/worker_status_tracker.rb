module WorkerStatusTracker
  extend ActiveSupport::Concern
  included do
    attr_reader :current_user

    def self.perform_later(*args)
      jid = perform_async(*args)
      if jid
        begin
          JobStatus.find_or_create_matching(current_user(*args), name, args)
        rescue ActiveRecord::RecordNotUnique => e
          # no need to retry
        end
      end
      jid
    end

    def perform(*args)
      @current_user = self.class.current_user(*args)
      # this indicates that the record has been deleted so can be ignored
      # Rollbar.warning("#{self.class.name} does not have a current_user!", args: args) unless current_user

      begin
        @job_status = JobStatus.find_or_create_matching(current_user, self.class.name, args) if current_user
      rescue ActiveRecord::RecordNotUnique => e
        retry
      end

      @job_status.try :executing!
      begin
        process(*args)
        @job_status.try :success!
      rescue QuitWorkerSignal
        puts "job replaced by another - quitting"
        # do nothing - this error means job is being replaced by another so we want to quit silently
      rescue => e
        @job_status.try :error!
        raise
      end
    end
  end
end
