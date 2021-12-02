module Api
  class BaseController < ActionController::API
    protected

    def bad_args(message)
      raise ArgumentError.new(message)
    end
  end
end
