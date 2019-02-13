FactoryBot.define do
  factory :namespace do
    sequence(:name) { |n| "namespace#{n}" }
    path { name.downcase.gsub(/\s/, '_') }

    # This is a workaround to avoid the user creating another namespace via
    # User#ensure_namespace_correct. We should try to remove it and then
    # we could remove this workaround
    association :owner, factory: :user, strategy: :build
    before(:create) do |namespace|
      owner = namespace.owner

      if owner
        # We're changing the username here because we want to keep our path,
        # and User#ensure_namespace_correct would change the path based on
        # username, so we're forced to do this otherwise we'll need to change
        # a lot of existing tests.
        owner.username = namespace.path
        owner.namespace = namespace
      end
    end

    trait :with_build_minutes do
      namespace_statistics factory: :namespace_statistics, shared_runners_seconds: 400.minutes.to_i
    end

    trait :with_build_minutes_limit do
      shared_runners_minutes_limit 500
    end

    trait :with_not_used_build_minutes_limit do
      namespace_statistics factory: :namespace_statistics, shared_runners_seconds: 300.minutes.to_i
      shared_runners_minutes_limit 500
    end

    trait :with_used_build_minutes_limit do
      namespace_statistics factory: :namespace_statistics, shared_runners_seconds: 1000.minutes.to_i
      shared_runners_minutes_limit 500
    end

    # EE-specific start
    transient do
      plan nil
    end

    before :create do |namespace, evaluator|
      if evaluator.plan.present?
        namespace.plan = create(evaluator.plan)
      end
    end

    after :create do |namespace, evaluator|
      if evaluator.plan.present?
        create(:gitlab_subscription, namespace: namespace, hosted_plan: namespace.plan)
      end
    end
    # EE-specific end
  end
end
