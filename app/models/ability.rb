class Ability
  include CanCan::Ability

  def initialize(user)
    self.clear_aliased_actions
    alias_action :index, :show, to: :display
    alias_action :create, :update, to: :modify

    can :display, Currency
    can :display, Country
    can :display, WalletService
    can :display, LiveMarketRate
    can :display, Plan

    if user.is_a? User
      can :manage, User, id: user.id
      can :manage, Report, user_id: user.id
      can :manage, CapitalGainsReport, user_id: user.id
      can :manage, TransactionsReport, user_id: user.id
      can :manage, Transaction, user_id: user.id
      can :manage, Wallet, user_id: user.id
      can :manage, CsvImport, user_id: user.id
      can :display, Asset, user_id: user.id
      can :display, Entry, user_id: user.id
      can :display, JobStatus, user_id: user.id
      can :manage, Subscription, user_id: user.id
    else
      can :create, User
    end
  end
end
