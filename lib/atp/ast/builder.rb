module ATP
  module AST
    class Builder
      include Factories

      attr_reader :context
      attr_accessor :source_file, :source_line_number, :description

      def initialize
        @context = { conditions: [] }
      end

      def flow(str)
        n(:flow, name(str))
      end

      def name(str)
        n(:name, str.to_s)
      end

      def log(str, options = {})
        test = n(:log, str.to_s)
        if options[:conditions]
          apply_conditions(test, options[:conditions])
        else
          test
        end
      end

      def render(str)
        n(:render, str)
      end

      def id(symbol)
        n(:id, symbol.to_sym)
      end

      def flow_flag(name, enabled, node)
        n(:flow_flag, name, enabled, node)
      end

      def test_result(id, passed, node)
        n(:test_result, id, passed, node)
      end

      def test_executed(id, executed, node)
        n(:test_executed, id, executed, node)
      end

      def job(id, enabled, node)
        n(:job, id, enabled, node)
      end

      def run_flag(id, enabled, node)
        n(:run_flag, id, enabled, node)
      end

      def set_run_flag(flag)
        n(:set_run_flag, flag)
      end

      def enable_flow_flag(var, options = {})
        test = n(:enable_flow_flag, var)
        if options[:conditions]
          apply_conditions(test, options[:conditions])
        else
          test
        end
      end

      def disable_flow_flag(var, options = {})
        test = n(:disable_flow_flag, var)
        if options[:conditions]
          apply_conditions(test, options[:conditions])
        else
          test
        end
      end

      def group(group_name, nodes, options = {})
        children = [name(group_name)]

        children << id(options[:id].to_s.downcase.to_sym) if options[:id]

        children << on_fail(options[:on_fail]) if options[:on_fail]
        children << on_pass(options[:on_pass]) if options[:on_pass]

        children += nodes
        group = n(:group, *children)

        if options[:conditions]
          apply_conditions(group, options[:conditions])
        else
          group
        end
      end

      def cz(setup, node, options = {})
        test = n(:cz, setup, node)
        if options[:conditions]
          apply_conditions(test, options[:conditions])
        else
          test
        end
      end

      def new_context
        @context = { conditions: [] }
        yield if block_given?
        @context
      end

      CONDITION_KEYS = [
        :if_enabled, :enabled, :enable_flag, :enable, :if_enable,
        :unless_enabled, :not_enabled, :disabled, :disable, :unless_enable,
        :if_failed, :unless_passed, :failed,
        :if_passed, :unless_failed, :passed,
        :if_ran, :if_executed,
        :unless_ran, :unless_executed,
        :job, :jobs, :if_job, :if_jobs,
        :unless_job, :unless_jobs,
        :if_any_failed, :unless_all_passed,
        :if_all_failed, :unless_any_passed,
        :if_any_passed, :unless_all_failed,
        :if_all_passed, :unless_any_failed,
        :if_flag, :unless_flag
      ]

      def apply_conditions(node, conditions)
        conditions.each do |key, value|
          # Sometimes conditions can be an array (in the case of the current context
          # being re-used), so rectify that now
          if key.is_a?(Hash)
            fail 'Something has gone wrong applying the test conditions' if key.size > 1
            key, value = key.first[0], key.first[1]
          end
          key = key.to_s.downcase.to_sym
          # Represent all condition values as lower cased strings internally
          if value.is_a?(Array)
            value = value.map { |v| v.to_s.downcase }
          else
            value = value.to_s.downcase
          end
          context[:conditions] << { key => value }
          case key
          when :if_enabled, :enabled, :enable_flag, :enable, :if_enable
            node = flow_flag(value, true, node)
          when :unless_enabled, :not_enabled, :disabled, :disable, :unless_enable
            node = flow_flag(value, false, node)
          when :if_failed, :unless_passed, :failed
            if value.is_a?(Array)
              fail 'if_failed only accepts one ID, use if_any_failed or if_all_failed for multiple IDs'
            end
            node = test_result(value, false, node)
          when :if_passed, :unless_failed, :passed
            if value.is_a?(Array)
              fail 'if_passed only accepts one ID, use if_any_passed or if_all_passed for multiple IDs'
            end
            node = test_result(value, true, node)
          when :if_any_failed, :unless_all_passed
            node = test_result(value, false, node)
          when :if_all_failed, :unless_any_passed
            node = value.reduce(nil) do |nodes, val|
              test_result(val, false, nodes ? nodes : node)
            end
          when :if_any_passed, :unless_all_failed
            node = test_result(value, true, node)
          when :if_all_passed, :unless_any_failed
            node = value.reduce(nil) do |nodes, val|
              test_result(val, true, nodes ? nodes : node)
            end
          when :if_ran, :if_executed
            node = test_executed(value, true, node)
          when :unless_ran, :unless_executed
            node = test_executed(value, false, node)
          when :job, :jobs, :if_job, :if_jobs
            node = job(value, true, node)
          when :unless_job, :unless_jobs
            node = job(value, false, node)
          when :if_flag
            if value.is_a?(Array)
              fail 'if_flag only accepts one flag'
            end
            node = run_flag(value, true, node)
          when :unless_flag
            if value.is_a?(Array)
              fail 'unless_flag only accepts one flag'
            end
            node = run_flag(value, false, node)
          else
            fail "Unknown test condition attribute - #{key} (#{value})"
          end
        end
        node
      end

      def test(object, options = {})
        children = [n(:object, object)]

        n = (options[:name] || options[:tname] || options[:test_name])
        unless n
          [:name, :tname, :test_name].each do |m|
            n ||= object.respond_to?(m) ? object.send(m) : nil
          end
        end
        children << name(n) if n

        n = (options[:number] || options[:num] || options[:tnum] || options[:test_number])
        unless n
          [:number, :num, :tnum, :test_number].each do |m|
            n ||= object.respond_to?(m) ? object.send(m) : nil
          end
        end
        children << number(n) if n

        children << id(options[:id].to_s.downcase.to_sym) if options[:id]

        children << on_fail(options[:on_fail]) if options[:on_fail]
        children << on_pass(options[:on_pass]) if options[:on_pass]

        test = n(:test, *children)

        if options[:conditions]
          apply_conditions(test, options[:conditions])
        else
          test
        end
      end

      def on_fail(options = {})
        children = []
        if options[:bin] || options[:softbin]
          fail_opts = { bin: options[:bin], softbin: options[:softbin] }
          fail_opts[:bin_description] = options[:bin_description] if options[:bin_description]
          fail_opts[:softbin_description] = options[:softbin_description] if options[:softbin_description]
          children << set_result(:fail, fail_opts)
        end
        if options[:set_run_flag] || options[:set_flag]
          children << set_run_flag(options[:set_run_flag] || options[:set_flag])
        end
        children << continue if options[:continue]
        children << render(options[:render]) if options[:render]
        n(:on_fail, *children)
      end

      def on_pass(options = {})
        children = []
        if options[:bin] || options[:softbin]
          pass_opts = { bin: options[:bin], softbin: options[:softbin] }
          pass_opts[:bin_description] = options[:bin_description] if options[:bin_description]
          pass_opts[:softbin_description] = options[:softbin_description] if options[:softbin_description]
          children << set_result(:pass, pass_opts)
        end
        if options[:set_run_flag] || options[:set_flag]
          children << set_run_flag(options[:set_run_flag] || options[:set_flag])
        end
        children << continue if options[:continue]
        children << render(options[:render]) if options[:render]
        n(:on_pass, *children)
      end

      def set_result(type, options = {})
        children = []
        children << type
        if options[:bin] && options[:bin_description]
          children << n(:bin, options[:bin], options[:bin_description])
        else
          children << n(:bin, options[:bin]) if options[:bin]
        end
        if options[:softbin] && options[:softbin_description]
          children << n(:softbin, options[:softbin], options[:softbin_description])
        else
          children << n(:softbin, options[:softbin]) if options[:softbin]
        end
        result = n(:set_result, *children)

        if options[:conditions]
          apply_conditions(result, options[:conditions])
        else
          result
        end
      end

      def number(val)
        n(:number, val.to_i)
      end

      def continue
        n0(:continue)
      end
    end
  end
end
