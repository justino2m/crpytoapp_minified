class InvestmentsUpdater
  def self.call(user, &block)
    calculator = Investment.calculator_class(user.cost_basis_method)
    calculator.new(user).process(&block)
  end
end
