# frozen_string_literal: true

class War < Sequel::Model
  include Rogare::Utilities

  many_to_one :creator, class: :User
  many_to_one :canceller, class: :User
  many_to_many :members, join_table: :wars_members, right_key: :user_id, class: :User

  def self.all_existing
    where { (ended =~ false) & (cancelled =~ nil) }.order_by(:created)
  end

  def self.all_current
    all_existing.where do
      (start + concat(seconds, ' secs').cast(:interval) > now.function)
    end
  end

  def self.start_timers_for_existing
    all_existing.map(&:start_timer)
  end

  def finish
    start + seconds.seconds
  end

  def til_start
    start - Time.now
  end

  def til_finish
    finish - Time.now
  end

  def current?
    !cancelled && finish > Time.now
  end

  def future?
    current? && start > Time.now
  end

  def others
    members.reject { |u| u == creator }
  end

  def discord_channels
    channels.map do |c|
      chan = Rogare.find_channel(c)
      next chan if chan && !chan.is_a?(Array)
    end.compact
  end

  def broadcast(msg)
    discord_channels.each { |chan| chan.send msg }
  end

  def start!
    self.started = true
    save
  end

  def finish!
    self.ended = true
    save
  end

  def cancel!(by_user)
    self.canceller = by_user
    self.cancelled = Time.now
    save
  end

  def add_member!(user)
    return if members.include? user

    add_member user
  end

  def add_channel(chan)
    self.channels = channels.push(chan).uniq
  end

  def start_timer
    Thread.new do
      next if cancelled

      reply = ->(msg) { broadcast msg }

      starting = lambda { |time, &block|
        refresh
        next unless current?

        extra = '' + (block.call unless block.nil?)
        reply.call "Wordwar #{id} is starting #{time}! #{members.map(&:mid).join(', ')}#{extra}"
      }

      ending = lambda {
        refresh
        next if cancelled

        reply.call "Wordwar #{id} has ended! #{members.map(&:mid).join(', ')}"
      }

      if til_start.positive?
        # We're before the start of the war

        if til_start > 35
          # If we're at least 35 seconds before the start, we have
          # time to send a reminder. Otherwise, skip sending it.
          sleep til_start - 30
          starting.call('in 30 seconds') { '— Be ready: tell us your starting wordcount.' }
          sleep 30
        else
          # In any case, we sleep until the beginning
          sleep til_start
        end

        starting.call('now') { "(for #{dur_display(finish, start).first})" }
        start!
        sleep seconds
        ending.call
        finish!
      elsif til_finish.negative? && !ended
        # We're after the END of the war, but the war is not marked
        # as ended, so it must be that the war ended as the bot was
        # restarting! Oh no. That means we're probably a bit late.
        ending.call
        finish!
      else
        # We're AFTER the start of the war. Probably because the
        # bot restarted while a war was running.

        unless started
          # The war is not marked as started but it is started, so
          # the bot probably restarted at the exact moment the war
          # was supposed to start. That means we're probably late.
          starting.call 'just now'
          start!
        end

        sleep til_finish
        ending.call
        finish!
      end
    end
  end
end