# frozen_string_literal: true

class Ability
  include CanCan::Ability

  # What a moderator may look at. Users, bans and personal details are deliberately not here.
  MODERATED_RESOURCES = [Product, Category, Comment, Order, Item, Payment, Refund, Invoice].freeze

  def initialize(user)
    alias_action :update_location, :update_details, :update_entrepreneur_details, to: :update_specifics
    alias_action :me, :logout, :actions, to: :profile_actions
    alias_action :mark_order_status, :mark_payment_status, to: :mark_status

    user ||= User.new

    can :read, Product
    can :create, User

    return unless user.persisted?

    if user.activated?
      can %i[like unlike rate comment], Product
      can %i[manage update_specifics profile_actions], User, id: user.id
    end

    if user.verified?
      can :manage, :cart
      can :create, Payment
      can :read, Payment, order: { user_id: user.id }
      can :create, Refund
      can %i[show cancel], Refund, user_id: user.id
      can %i[read download], Invoice, user_id: user.id
      can %i[create read cancel], Order, user_id: user.id
    end

    if user.admin?
      can :manage, :all
    elsif user.moderator?
      can :read, MODERATED_RESOURCES
      can :update, [Product, Order, Payment, Refund]
      can :mark_status, Order
      can %i[complete], Refund
      can :manage, Comment
      can :manage, Category
    elsif user.regular? || user.entrepreneur?
      can :read, Comment
      can :read, Item, user_id: user.id
      can %i[update destroy], Comment, user_id: user.id
      cannot :index, User
      cannot :role, User
    end
  end
end
