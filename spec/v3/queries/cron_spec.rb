describe Travis::API::V3::Queries::Crons do
  let(:query) { Travis::API::V3::Queries::Crons.new({}, 'Overview') }
  let(:error) { StandardError.new("Konstantin broke all the thingz!") }
  let!(:scheduler_interval) { Travis::API::V3::Cron::SCHEDULER_INTERVAL + 1.minute }
  describe "scheduled_crons" do
    it "collects all upcoming cron jobs" do
      cron1 = Factory(:cron)
      cron2 = Factory(:cron)

      cron2.update_attribute(:next_run, 2.hours.from_now)
      Timecop.travel(scheduler_interval.from_now)
      query.scheduled_crons.count.should eql 1
      Timecop.return
      cron1.destroy
      cron2.destroy
    end
  end
end
