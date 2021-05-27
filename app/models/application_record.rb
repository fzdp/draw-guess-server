class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # e.g
  # result = User.validate_attributes(email:'hello@test.com')
  # if !result[0]
  #   errors = result[1].to_hash # {:email => [邮箱已经被占用]}
  # end
  def self.validate_attributes(attributes)
    obj = self.new(attributes)
    return [true, obj.errors] if obj.valid?

    obj.errors.slice! *attributes.keys
    [obj.errors.blank?, obj.errors]
  end

  def self.valid_attributes?(attributes)
    obj = self.new(attributes)
    return true if obj.valid?
    obj.errors.slice! *attributes.keys
    obj.errors.blank?
  end
end
