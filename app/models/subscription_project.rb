# frozen_string_literal: true

class SubscriptionProject < Project
  include Project::BaseValidator
  has_many :subscriptions, primary_key: :common_id, foreign_key: :project_id
  has_many :subscription_payments, through: :subscriptions
  has_many :subscription_payment_transitions, through: :subscription_payments
  has_many :subscription_transitions, through: :subscriptions
  accepts_nested_attributes_for :goals, allow_destroy: true
  mount_uploader :cover_image, CoverUploader
  # delegate reusable methods from state_machine
  delegate :push_to_online, :push_to_draft, :finish,
           :push_to_trash, to: :state_machine

  def self.sti_name
    'sub'
  end

  # instace of a subscription project state machine
  def state_machine
    @state_machine ||= SubProjectMachine.new(self, {
                                                transition_class: ProjectTransition
                                              })
  end

  #@TODO move to db view
  def pledged
    sum = 0
    subscriptions.where(status: 'active').each do |subscription|
      paid_or_pending = subscription.subscription_payments.where(status: ['paid', 'pending']).order(:created_at).last 
      sum += paid_or_pending.data['amount'].to_f/100.0 if paid_or_pending.present?
    end
    sum
  end

  def current_goal
    goals.order('value asc').where('value > ?', pledged).first || goals.order('value desc').first
  end

  def progress
    ((pledged / current_goal.value) * 100).floor
  end
end
