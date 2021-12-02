require 'rails_helper'

RSpec.describe PermaLock, type: :model do
  let(:lock) { create(:permalock) }

  describe 'validations' do
    xit "should succeed" do
      expect(lock.save).to be true
    end

    xit "should fail if name not present" do
      lock.name = ''
      expect(lock.save).to be false
    end

    xit "should fail if name not unique" do
      lock.save!
      expect(lock.dup.save).to be false
    end
  end

  describe '#stale' do
    xit "should return expired locks" do
      lock.save!
      lock.update_column(:stale_at, 5.minutes.ago)
      lock2 = create(:permalock, name: 'hello2')
      expect(PermaLock.stale).to include lock
      expect(PermaLock.stale).not_to include lock2
    end
  end

  describe '#active' do
    xit "should return locks that have not expired" do
      lock.save!
      lock.update_column(:stale_at, 5.minutes.ago)
      lock2 = create(:permalock, name: 'hello2')
      expect(PermaLock.active).not_to include lock
      expect(PermaLock.active).to include lock2
    end
  end

  describe '#locked?' do
    subject { PermaLock.locked?('hello') }

    before do
      lock.save!
    end

    xit "should return true if lock exists" do
      expect(subject).to be true
    end

    xit "should return false if lock exists but expired" do
      lock.update_attributes!(stale_at: 5.minutes.ago)
      expect(subject).to be false
    end
  end

  describe '#lock' do
    subject { PermaLock.lock('yolo') }

    xit "should return a lock" do
      expect(subject).to be_a PermaLock
    end

    xit "should return nil if lock cant be created" do
      expect(PermaLock.lock('yolo')).not_to be_nil
      expect(PermaLock.lock('yolo')).to be_nil
    end

    xit "should poll for the specified number of seconds before returning" do
      subject
      t = Time.now
      expect(PermaLock.lock('yolo', wait: 1)).to be_nil
      expect((Time.now - t).to_i).to eq 1
    end
  end

  describe '#lock!' do
    xit "should raise error if unable to lock" do
      PermaLock.lock!(:yo)
      expect{PermaLock.lock!(:yo)}.to raise_error PermaLock::LockTimeout
    end
  end

  describe '#with_lock!' do
    subject { PermaLock.with_lock!('yo') {} }

    xit "should run the specified block if lock was created" do
      expect{ |b| PermaLock.with_lock!('yo', &b) }.to yield_control
    end

    xit "should destroy lock after block has finished running" do
      expect_any_instance_of(PermaLock).to receive(:destroy).and_call_original
      subject
    end

    xit "should raise error if lock creation failed" do
      PermaLock.lock('yo')
      expect{subject}.to raise_error PermaLock::LockTimeout
    end

    xit "should destroy lock if exception occurs in yield block" do
      expect_any_instance_of(PermaLock).to receive(:destroy).and_call_original
      expect{PermaLock.with_lock!('yo') { raise 'yo' } }.to raise_error 'yo'
    end
  end

  describe '#acquire_lock' do
    subject { PermaLock.send(:acquire_lock, 'yo') }

    xit "should delete all stale locks" do
      l1 = PermaLock.lock('yo')
      l2 = PermaLock.lock('hi')
      l1.update_attributes!(stale_at: 10.minutes.ago)
      expect{subject}.to change{PermaLock.stale.count}.by -1
      subject
    end

    xit "should create a lock using an objects global id" do
      user = create(:user)
      lk = PermaLock.send(:acquire_lock, user)
      expect(lk.name).to eq user.to_global_id.to_s
      expect(PermaLock.send(:acquire_lock, user)).to be_nil
    end

    xit "should create lock with to_s if no global id" do
      expect(PermaLock).to receive(:create!).with(hash_including(name: 'yo')).and_call_original
      lock = PermaLock.send(:acquire_lock, :yo)
      expect(lock.name).to eq 'yo'
    end

    xit "should return nil if lock was not created" do
      create(:permalock, name: 'yo')
      expect(subject).to eq nil
    end
  end

  describe 'raise_lock_error' do
    subject { PermaLock.send(:raise_lock_error, user) }

    xit "should raise error with friendly message for db records" do
      user = create(:user)
      expect{PermaLock.send(:raise_lock_error, user)}.to raise_error PermaLock::LockTimeout, "User[#{user.id}] is locked!"
    end

    xit "should print object string for non-db records" do
      expect{PermaLock.send(:raise_lock_error, :yo)}.to raise_error PermaLock::LockTimeout, 'yo is locked!'
    end
  end
end
