# frozen_string_literal: true

class BlockList < ApplicationRecord
  # Polymorphic associations
  belongs_to :blocker, polymorphic: true
  belongs_to :blocked, polymorphic: true

  # Validations
  validates :blocker_type, :blocker_id, :blocked_type, :blocked_id, presence: true
  validates :blocker_id, uniqueness: {
    scope: [:blocker_type, :blocked_type, :blocked_id],
    message: 'This block already exists'
  }
  validate :cannot_block_self

  # Scopes
  scope :for_blocker, ->(blocker) { where(blocker: blocker) }
  scope :for_blocked, ->(blocked) { where(blocked: blocked) }
  scope :between, ->(entity1, entity2) {
    where(blocker: entity1, blocked: entity2)
      .or(where(blocker: entity2, blocked: entity1))
  }

  # Class methods
  def self.blocked?(blocker, blocked)
    exists?(blocker: blocker, blocked: blocked)
  end

  def self.blocking_exists_between?(entity1, entity2)
    between(entity1, entity2).exists?
  end

  # Helper to check if a worker is blocked by or blocking a company
  def self.worker_company_blocked?(worker_profile, company)
    exists?(blocker: worker_profile, blocked: company) ||
      exists?(blocker: company, blocked: worker_profile)
  end

  private

  def cannot_block_self
    if blocker_type == blocked_type && blocker_id == blocked_id
      errors.add(:base, 'Cannot block yourself')
    end
  end
end
