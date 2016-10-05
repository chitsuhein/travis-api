require "sentry-raven"

describe Travis::API::V3::Services::Crons::Start do
  let(:error) { StandardError.new("Konstantin broke all the thingz!") }
  let!(:scheduler_interval) { Travis::API::V3::Cron::SCHEDULER_INTERVAL + 1.minute }
  let(:subject) { Travis::API::V3::Services::Crons::Start.new nil, nil, nil }

  describe "enqueue all" do
    it "raises exception when enqueue method errors" do
      cron1 = Factory(:cron)
      Timecop.travel(scheduler_interval.from_now)
      subject.expects(:sleep).with(10)
      Travis::API::V3::Models::Cron.any_instance.stubs(:enqueue).raises(error)
      Raven.expects(:capture_exception).with(error, tags: {'cron_id' => cron1.id })
      subject.enqueue_all
      Timecop.return
      cron1.destroy
    end

    it 'continues running crons if one breaks' do
      cron1 = Factory(:cron)
      cron2 = Factory(:cron)
      Timecop.travel(scheduler_interval.from_now)
      Travis::API::V3::Models::Cron.any_instance.stubs(:branch).raises(error)
      subject.expects(:sleep).twice.with(10)

      Raven.expects(:capture_exception).with(error, tags: {'cron_id' => cron1.id })
      Raven.expects(:capture_exception).with(error, tags: {'cron_id' => cron2.id })
      subject.enqueue_all
      Timecop.return
      cron1.destroy
      cron2.destroy
    end

    context "dont_run_if_recent_build_exists is true" do
      let!(:cron) { Factory(:cron, dont_run_if_recent_build_exists: true) }

      before { Timecop.freeze(DateTime.now) }

      context "no new build in the last 24h" do
        before do
          last_build = Factory.create(:build,
            repository_id: cron.branch.repository.id,
            finished_at: DateTime.now - 1.hour)
          cron.branch.update_attribute(:last_build_id, last_build.id)
          Timecop.travel(scheduler_interval.from_now)
        end

        after { Timecop.return }
        it "skips enqueuing a cron job" do
          Sidekiq::Client.any_instance.expects(:push).never
          subject.enqueue_all
        end

        it "schedules the next cron job" do
          subject.enqueue_all
          cron.reload
          expect(cron.next_run.to_i).to eql (Time.now.utc + 1.day).to_i
        end
      end
    end
  end
end
