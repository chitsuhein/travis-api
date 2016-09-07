require 'sentry-raven'

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

  describe "enqueue all" do
    it "raises exception when enqueue method errors" do
      cron1 = Factory(:cron)
      Timecop.travel(scheduler_interval.from_now)
      Travis::API::V3::Queries::Crons.any_instance.expects(:sleep).with(10)
      Travis::API::V3::Models::Cron.any_instance.stubs(:enqueue).raises(error)
      Raven.expects(:capture_exception).with(error, tags: {'cron_id' => cron1.id })
      query.enqueue_all
      Timecop.return
      cron1.destroy
    end

    it 'continues running crons if one breaks' do
      cron1 = Factory(:cron)
      cron2 = Factory(:cron)
      Timecop.travel(scheduler_interval.from_now)
      Travis::API::V3::Models::Cron.any_instance.stubs(:branch).raises(error)
      Travis::API::V3::Queries::Crons.any_instance.expects(:sleep).twice.with(10)

      Raven.expects(:capture_exception).with(error, tags: {'cron_id' => cron1.id })
      Raven.expects(:capture_exception).with(error, tags: {'cron_id' => cron2.id })
      query.enqueue_all
      Timecop.return
      cron1.destroy
      cron2.destroy
    end

    context "run_only_when_new_commit is true" do
      let!(:cron) { Factory(:cron, run_only_when_new_commit: true) }

      before { Timecop.freeze(DateTime.now) }

      context "no new commit since last non cron build" do
        before do
          last_build = Factory.create(:build,
            repository_id: cron.branch.repository.id,
            finished_at: DateTime.now.utc - 10.minutes)
          cron.branch.update_attribute(:last_build_id, last_build.id)
          Timecop.travel(scheduler_interval.from_now)
        end

        after { Timecop.return }
        it "skips enqueuing a cron job" do
          Sidekiq::Client.any_instance.expects(:push).never
          query.enqueue_all
        end

        it "schedules the next cron job" do
          query.enqueue_all
          cron.reload
          expect(cron.next_run.to_i).to eql (Time.now.utc + 1.day - 10.minutes - scheduler_interval).to_i
        end
      end
    end
  end
end
