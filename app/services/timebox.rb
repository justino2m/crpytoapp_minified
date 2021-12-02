class Timebox
  def self.run(name=nil)
    t1 = Time.now
    yield
    t2 = Time.now
    puts "Finished task #{name} in #{t2 - t1} seconds"
  end
end