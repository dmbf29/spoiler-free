class Sport < ApplicationRecord
  has_many :competitions, dependent: :destroy
  has_many :videos, through: :competitions

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :ensure_slug

  private

  def ensure_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
