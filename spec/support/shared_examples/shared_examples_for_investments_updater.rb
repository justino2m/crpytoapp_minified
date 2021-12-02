RSpec.shared_examples "investments_updater" do
  it "should generate investments" do
    subject
    compare_investments(self)
  end
end

RSpec.shared_examples "fifo" do |realize_gains=false|
  let(:user) { create(:user, cost_basis_method: Investment::FIFO, realize_gains_on_exchange: realize_gains) }
  include_examples 'investments_updater'
end

RSpec.shared_examples "lifo" do |realize_gains=false|
  let(:user) { create(:user, cost_basis_method: Investment::LIFO, realize_gains_on_exchange: realize_gains) }
  include_examples 'investments_updater'
end

RSpec.shared_examples "acb" do |realize_gains=false|
  let(:user) { create(:user, cost_basis_method: Investment::AVERAGE_COST, realize_gains_on_exchange: realize_gains) }
  include_examples 'investments_updater'
end

RSpec.shared_examples "fifo_ireland" do |realize_gains=false|
  let(:user) { create(:user, cost_basis_method: Investment::FIFO_IRELAND, realize_gains_on_exchange: realize_gains) }
  include_examples 'investments_updater'
end

RSpec.shared_examples "shared_pool" do |realize_gains=false|
  let(:user) { create(:user, cost_basis_method: Investment::SHARED_POOL, realize_gains_on_exchange: realize_gains) }
  include_examples 'investments_updater'
end

RSpec.shared_examples "acb_canada" do |realize_gains=false|
  let(:user) { create(:user, cost_basis_method: Investment::ACB_CANADA, realize_gains_on_exchange: realize_gains) }
  include_examples 'investments_updater'
end

# can pass suffix instead of example too
def compare_investments(context, example=nil, suffix=nil)
  snapshot = {}
  q = user.investments.order(date: :asc, id: :asc).without_subtype(Investment::WASH_SALE)
  Currency.where(id: q.select(:currency_id)).order(symbol: :asc).each do |curr|
    snapshot[curr.symbol] = q.where(currency: curr).map do |inv|
      if inv.deposit?
        s = "#{inv.date}: +#{inv.amount}, value: #{inv.value}"
        s += "      Extracted #{inv.extracted_amount} worth #{inv.extracted_value}"
      else
        s = "#{inv.date}: #{inv.amount}, value: #{inv.value}, gain: #{inv.gain}"
        extra = []
        extra << "From lot of #{inv.from.amount} on #{inv.from_date}" if inv.from
        extra << "Pool: #{inv.pool_name}" if inv.pool_name
        extra << "Subtype: #{inv.subtype}" if inv.subtype
        extra << "Long term!" if inv.long_term
        s += "      " + extra.join(', ') if extra.any?
      end
      s
    end
  end

  path = context.class.to_s.gsub('RSpec::ExampleGroups::', '').underscore
  path += "/#{example.description.gsub(' ', '_')}" if example && example.respond_to?(:description)
  path += "_#{suffix || example}" if suffix || example.is_a?(String)
  expect(snapshot).to match_snapshot('investments/' + path)
end