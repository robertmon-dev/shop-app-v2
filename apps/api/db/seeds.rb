# frozen_string_literal: true

ADMIN_MAIL = ENV.fetch('ADMIN_MAIL')

Rails.logger.info 'Clearing database'
Rails.application.eager_load!
models = ApplicationRecord.descendants

ActiveRecord::Base.transaction do
  ActiveRecord::Base.connection.execute("SET session_replication_role = 'replica';")

  models.each do |model|
    model.delete_all
    Rails.logger.info "All records from #{model.name} have been deleted."
  end

  ActiveRecord::Base.connection.execute("SET session_replication_role = 'origin';")
end

User.find_or_create_by!(mail: ADMIN_MAIL) do |user|
  user.password = ENV.fetch('ADMIN_PASSWORD')
  user.role = :admin
  user.active = true
  user.verified = true

  user.build_user_detail(name: 'Admin',
                         first_name: ENV.fetch('ADMIN_FIRST_NAME'),
                         last_name: ENV.fetch('ADMIN_LAST_NAME'))
  user.build_user_settings(
    two_factor: true,
    night_mode: false
  )

  Rails.logger.info "Admin user '#{user.mail}' created successfully."
end

Rails.logger.info 'Cleared database'
