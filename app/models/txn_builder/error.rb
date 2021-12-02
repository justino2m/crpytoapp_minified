module TxnBuilder
  class Error < ArgumentError
    attr_accessor :errors, :txn

    def initialize(record)
      if record.is_a? String
        super(record)
      else
        self.txn = record if record.is_a? Transaction
        self.errors = record.errors
        super(errors.full_messages.join(', '))
      end
    end
  end
end
