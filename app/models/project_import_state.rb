class ProjectImportState < ActiveRecord::Base
  include AfterCommitQueue

  self.table_name = "project_mirror_data"

  prepend EE::ProjectImportState

  belongs_to :project

  validates :project, presence: true

  scope :with_started_status, -> { where(status: :started) }

  state_machine :status, initial: :none do
    event :schedule do
      transition [:none, :finished, :failed] => :scheduled
    end

    event :force_start do
      transition [:none, :finished, :failed] => :started
    end

    event :start do
      transition scheduled: :started
    end

    event :finish do
      transition started: :finished
    end

    event :fail_op do
      transition [:scheduled, :started] => :failed
    end

    state :scheduled
    state :started
    state :finished
    state :failed

    after_transition [:none, :finished, :failed] => :scheduled do |state, _|
      state.run_after_commit do
        job_id = project.add_import_job
        update(jid: job_id) if job_id
      end
    end

    after_transition started: :finished do |state, _|
      project = state.project

      project.reset_cache_and_import_attrs

      if Gitlab::ImportSources.importer_names.include?(project.import_type) && project.repo_exists?
        state.run_after_commit do
          Projects::AfterImportService.new(project).execute
        end
      end
    end
  end

  def import_in_progress?
    started? || scheduled?
  end

  def refresh_jid_expiration
    return unless jid

    Gitlab::SidekiqStatus.set(jid, StuckImportJobsWorker::IMPORT_JOBS_EXPIRATION)
  end

  def remove_jid
    return unless jid

    Gitlab::SidekiqStatus.unset(jid)
    update_column(:jid, nil)
  end

  def mark_as_failed(error_message)
    original_errors = errors.dup
    sanitized_message = Gitlab::UrlSanitizer.sanitize(error_message)

    fail_op
    update_column(:last_error, sanitized_message)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("Error setting import status to failed: #{e.message}. Original error: #{sanitized_message}")
  ensure
    @errors = original_errors
  end
end
