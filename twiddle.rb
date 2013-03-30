require 'set'

class Twiddle
  def initialize(&block)
    @before = []
    @after = []
    @replace = []
    instance_eval(&block)
  end

  def before(target = nil, &block)
    @before << [target, block]
  end

  def after(target = nil, &block)
    @after << [target, block]
  end

  def replace(target = nil, &block)
    @replace << [target, block]
  end

  def attach(context)
    if context.is_a? Class
      attach_class(context)
    else
      attach_inst(context)
    end
  end

  def detach(context)
    if context.is_a? Class
      detach_class(context)
    end
  end

private
  def detach_class(klass)
  end

  def attach_class(klass)
    in_attach = true

    methods = klass.instance_methods + klass.private_instance_methods

    orig = {}
    latch = {}

    methods.each { |m|
      next if m == :define_method

      @before.each { |before|
        target, callback = before
        next if !affects(target, m)

        orig[m] = klass.instance_method(m)

        klass.send(:define_method, m) { |*args|
          method = orig[m].bind(self)
          if in_attach || latch[self]
            return method.call(*args)
          else
            latch[self] = true
            callback.call(method, *args)
            result = method.call(*args)
            latch[self] = false
            return result
          end
        }
      }
    }

    methods.each { |m|
      next if m == :define_method

      @after.each { |after|
        target, callback = after
        next if !affects(target, m)

        orig[m] = klass.instance_method(m)

        klass.send(:define_method, m) { |*args|
          method = orig[m].bind(self)
          if in_attach || latch[self]
            return method.call(*args)
          else
            latch[self] = true
            result = method.call(*args)
            result = callback.call(method, *args, result)
            latch[self] = false
            return result
          end
        }
      }
    }

    methods.each { |m|
      next if m == :define_method

      @replace.each { |replace|
        target, callback = replace
        next if !affects(target, m)

        orig[m] = klass.instance_method(m)

        klass.send(:define_method, m) { |*args|
          method = orig[m].bind(self)
          if in_attach || latch[self]
            method.call(*args)
          else
            latch[self] = true
            result = callback.call(method, *args)
            latch[self] = false
            return result
          end
        }
      }
    }

    in_attach = false
    return klass
  end

  def attach_inst(obj)
    in_attach = true

    methods = obj.class.instance_methods + obj.class.private_instance_methods

    orig = {}
    methods.each { |m|
      next if m == :define_singleton_method

      @before.each { |before|
        target, callback = before
        next if !affects(target, m)

        orig[m] = obj.method(m)

        obj.define_singleton_method(m) { |*args|
          method = orig[m]
          if in_attach
            return method.call(*args)
          else
            callback.call(method, *args)
            return method.call(*args)
          end
        }
      }
    }

    methods.each { |m|
      next if m == :define_singleton_method

      @after.each { |after|
        target, callback = after
        next if !affects(target, m)

        orig[m] = obj.method(m)

        obj.define_singleton_method(m) { |*args|
          method = orig[m]
          if in_attach
            return method.call(*args)
          else
            result = method.call(*args)
            return callback.call(method, *args, result)
          end
        }
      }
    }

    methods.each { |m|
      next if m == :define_singleton_method

      @replace.each { |replace|
        target, callback = replace
        next if !affects(target, m)

        orig[m] = obj.method(m)

        obj.define_singleton_method(m) { |*args|
          method = orig[m]
          if in_attach
            method.call(*args)
          else
            return callback.call(method, *args)
          end
        }
      }
    }

    in_attach = false
    return obj
  end

  def affects(target, method)
    case target
      when NilClass
        true
      when Regexp
        method =~ target
      when Symbol, String
        method == target
      when Array
        target.any? { |t| affects(t, method) }
      else
        false
    end
  end
end

class CallCount < Twiddle
  def initialize
    @counts = {}
    super do
      before do |meth, *args|
        @counts[meth] ||= 0
        @counts[meth] += 1
      end
    end
  end

  def counts
    @counts
  end
end

class CallTrace < Twiddle
  def initialize(out = $stdout)
    super() do
      before do |meth, *args|
        out.puts "#{meth.owner}##{meth.name}"
      end
    end
  end
end

# Twiddle.before('ok', :length) do |...|
# Twiddle.before(String, :length) do |...|
# Twiddle.before(String, /.*/, :public) do |...|
# Twiddle.replace(/log_.*/) do |...|

#Twiddle.new do
  # before /.*/, :public do |...|
#end

# tracer.attach(String)
# tracer.detach ...

# tracer.attach(String) do
#    ...
# end

#c = CallCount.new
#c.attach Fixnum

#puts 5+10

#c.detach Fixnum

#c.counts.each { |m, co|
  #puts "#{m}: #{co}"
#}

# Inspect arguments
# Inspect method, object
# Inspect return value
# Modify any of above
# Replace method
# Support new methods
# Support multiple before/after/replace
# Ability to detach/undo
