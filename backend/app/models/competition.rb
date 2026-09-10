class Competition < ApplicationRecord
  belongs_to :sport
  has_many :videos, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  has_one_attached :photo

  scope :active, -> { where(active: true) }

  before_validation :ensure_slug

  private

  def ensure_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
