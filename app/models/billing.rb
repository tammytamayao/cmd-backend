class Billing < ApplicationRecord
    belongs_to :subscriber
    has_many :payments, dependent: :destroy
end
