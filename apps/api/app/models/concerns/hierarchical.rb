# frozen_string_literal: true

module Hierarchical
  extend ActiveSupport::Concern

  included do
    belongs_to :parent, class_name: name, optional: true
    has_many :children, class_name: name, foreign_key: 'parent_id', dependent: :destroy
  end

  def parents
    ancestors = []
    current = parent
    while current
      ancestors << current
      current = current.parent
    end
    ancestors
  end

  def descendants
    children.flat_map { |child| [child] + child.descendants }
  end
end
