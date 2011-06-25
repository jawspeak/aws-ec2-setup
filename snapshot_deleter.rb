#!/usr/bin/env ruby
require 'AWS' #gem install amazon-ec2
require 'date'

class SnapshotDeleter
  DEFAULT_DAYS_TO_KEEP = 40
  def initialize(access_key, secret_key, created_from_volume, now, days_to_keep = DEFAULT_DAYS_TO_KEEP)
    @ec2 = AWS::EC2::Base.new(
      :access_key_id => access_key,
      :secret_access_key => secret_key)
    @created_from_volume = created_from_volume
    @now = now
    @days_to_keep = days_to_keep.to_i
  end

  def delete_old_snapshots
     snapshots = @ec2.describe_snapshots(:owner => 'self')['snapshotSet']['item']
     snapshots.reject!{|s| s['volumeId'] != @created_from_volume}
     snapshots.reject!{|s| DateTime.strptime(s['startTime'], '%Y-%m-%dT%H:%M:%S') > (@now - @days_to_keep)}
     snapshots.each do |snapshot|
       puts "[SnapshotDeleter] will delete #{snapshot}"
       @ec2.delete_snapshot(:snapshot_id => snapshot['snapshotId'])
     end
  end

  def self.check_args(args)
    if ![1, 2].member?(args.length)
      return "usage: ruby #{__FILE__} volume-id (ex: vol-133aff) [days to keep, default #{DEFAULT_DAYS_TO_KEEP}]"
    end
  end
end

if __FILE__ == $0
  if error = SnapshotDeleter::check_args(ARGV)
    puts error
    exit(1)
  end
  SnapshotDeleter.new(                     \
    ENV['AWS_ACCESS_KEY_ID'],              \
    ENV['AWS_SECRET_ACCESS_KEY'],          \
    ARGV[0],                               \
    DateTime.now,                          \
    ARGV[1]).delete_old_snapshots
end
