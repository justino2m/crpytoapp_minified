module Monetizable
  extend ActiveSupport::Concern

  module ClassMethods
    def monetize(attr, opts={})
      define_method("display_#{attr}") do |raw_opts={}|
        if opts[:with] && opts[:with].respond_to?(:call)
          proc = opts[:with]
          currency = instance_exec(&proc)
        elsif opts[:with].is_a? Symbol
          currency = send(opts[:with])
        elsif opts[:as].present?
          currency = opts[:as]
        else
          currency = try(:currency) || raise('missing currency')
        end
        Currency.format(send(attr), currency, raw_opts)
      end
    end
  end
end
