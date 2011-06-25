require 'test/unit'
require 'date'
$:.unshift File.dirname(__FILE__)
require 'snapshot_deleter'

$snapshots = {} #ugly global vars. Did not get defining the module in the testclass to work.
$delete_snap = []
$describe_opts
# fake test double for fun instead of using a mocking library
module AWS
  module EC2
    class Base
      def initialize(options); end
      def describe_snapshots(options); $describe_opts = options; $snapshots; end
      def delete_snapshot(options = {}); $delete_snap << options; end
    end
  end
end

class TestIContactStatsData < Test::Unit::TestCase
  FAKE_NOW = DateTime.parse('2011-07-01 14:00')

  def setup
    $snapshots.clear
    $delete_snap.clear
    $describe_opts = nil
    $snapshots.merge!({"xmlns"=>"http://ec2.amazonaws.com/doc/2010-08-31/",
     "requestId"=>"5bbbbbbb-0bbb-4b23-bfa2-66db4aefbbbb",
     "snapshotSet"=>
      {"item"=> []}
    })
    @one_snapshot = {"snapshotId"=>"snap-347b2aaa",
      "volumeId"=>"vol-2b3b0000",
      "status"=>"completed",
      "startTime"=>"2011-05-14T23:25:04.000Z",
      "progress"=>"100%",
      "ownerId"=>"998875000000",
      "volumeSize"=>"1",
      "description"=>nil,
      "tagSet"=>{"item"=>[{"key"=>"Name", "value"=>"test"}]}}
    $snapshots['snapshotSet']['item'] << @one_snapshot
  end

  def test_delete_one_snapshot
    SnapshotDeleter.new('x', 'x', 'vol-2b3b0000', FAKE_NOW).delete_old_snapshots
    assert_equal({:owner => 'self'}, $describe_opts)
    assert_equal([{:snapshot_id => 'snap-347b2aaa'}], $delete_snap)
  end

  def test_delete_all_snapshots
    $snapshots['snapshotSet']['item'] << {"snapshotId"=>"snap-9c4effff",
      "volumeId"=>"vol-2b3b0000",
      "status"=>"completed",
      "startTime"=>(FAKE_NOW - SnapshotDeleter::DEFAULT_DAYS_TO_KEEP - 1).to_s,
      "progress"=>"100%",
      "ownerId"=>"998875000000",
      "volumeSize"=>"1",
      "description"=>nil,
      "tagSet"=>{"item"=>[{"key"=>"Name", "value"=>"jusk1"}]}}
      SnapshotDeleter.new('x', 'x', 'vol-2b3b0000', FAKE_NOW).delete_old_snapshots
      assert_equal([{:snapshot_id => 'snap-347b2aaa'}, {:snapshot_id => 'snap-9c4effff'}], $delete_snap)
  end

  def test_delete_no_snapshots_because_all_from_another_volume
    $snapshots['snapshotSet']['item'][0]['volumeId'] = 'vol-someOther'
    SnapshotDeleter.new('x', 'x', 'vol-2b3b0000', FAKE_NOW).delete_old_snapshots
    assert_equal([], $delete_snap)
  end

  def test_delete_no_snapshots_because_within_X_days
    $snapshots['snapshotSet']['item'][0]['startTime'] = (FAKE_NOW - SnapshotDeleter::DEFAULT_DAYS_TO_KEEP + 1).to_s
    SnapshotDeleter.new('x', 'x', 'vol-2b3b0000', FAKE_NOW).delete_old_snapshots
    assert_equal([], $delete_snap)
  end

  def test_check_arguments_to_command
    assert_nil SnapshotDeleter::check_args(['vol-abcdef'])
    assert_nil SnapshotDeleter::check_args(['vol-abcdef', '20'])
    assert_match /usage: ruby.*/, SnapshotDeleter::check_args(['vol-abcdef', '30', 'xyz'])
    assert_match /usage: ruby.*volume-id/, SnapshotDeleter::check_args([])
  end
end
