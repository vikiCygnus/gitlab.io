class AvatarUploader < GitlabUploader
  include UploaderHelper
  include RecordsUploads::Concern
  include ObjectStorage::Concern
  prepend ObjectStorage::Extension::RecordsUploads

  storage_options Gitlab.config.uploads

  def exists?
    model.avatar.file && model.avatar.file.present?
  end

  # We set move_to_store and move_to_cache to 'false' to prevent stealing
  # the avatar file from a project when forking it.
  # https://gitlab.com/gitlab-org/gitlab-ce/issues/26158
  def move_to_store
    false
  end

  def move_to_cache
    false
  end

  private

  def dynamic_segment
    File.join(model.class.to_s.underscore, mounted_as.to_s, model.id.to_s)
  end
end
