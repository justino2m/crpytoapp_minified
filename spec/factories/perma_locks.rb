FactoryBot.define do
  factory :perma_lock, aliases: [:permalock] do
    name "hello"
    stale_at 10.minutes.from_now
  end
end
