require 'spec_helper'

describe 'The flow builder API' do
  it 'is alive' do
    prog = ATP::Program.new
    flow = prog.flow(:sort1)
    flow.program.should == prog
    flow.raw.should be
  end

  it "tests can be added" do
    flow = ATP::Program.new.flow(:sort1) 
    flow.test :test1, on_fail: { bin: 5 }
    flow.test :test2, on_fail: { bin: 6, continue: true }
    flow.raw.should ==
      s(:flow,
        s(:test,
          s(:object, "test1"),
          s(:on_fail,
            s(:set_result, "fail",
              s(:bin, 5)))),
        s(:test,
          s(:object, "test2"),
          s(:on_fail,
            s(:set_result, "fail",
              s(:bin, 6)),
            s(:continue))))
  end

  it "conditions can be specified" do
    flow = ATP::Program.new.flow(:sort1) 
    flow.test :test1, id: :t1
    flow.test :test2, id: "T2" # Test that strings will be accepted for IDs
    flow.test :test3, conditions: { if_enabled: "bitmap" }
    flow.test :test4, conditions: { unless_enabled: "bitmap", if_failed: :t1 }
    flow.raw.should ==
      s(:flow,
        s(:test,
          s(:object, "test1"),
          s(:id, :t1)),
        s(:test,
          s(:object, "test2"),
          s(:id, :t2)),
        s(:flow_flag, "bitmap", true,
          s(:test,
            s(:object, "test3"))),
        s(:test_result, :t1, false,
          s(:flow_flag, "bitmap", false,
            s(:test,
              s(:object, "test4")))))
  end

  it "groups can be added" do
    flow = ATP::Program.new.flow(:sort1) 
    flow.test :test1
    flow.group "g1", id: :g1 do
      flow.test :test2
      flow.test :test3
      flow.group "g2" do
        flow.test :test4
        flow.test :test5
      end
    end
    flow.ast.should ==
      s(:flow,
        s(:test,
          s(:object, "test1")),
        s(:group, 
          s(:name, "g1"),
          s(:id, :g1),
          s(:members,
            s(:test,
              s(:object, "test2")),
            s(:test,
              s(:object, "test3")),
            s(:group, 
              s(:name, "g2"),
              s(:members,
                s(:test,
                  s(:object, "test4")),
                s(:test,
                  s(:object, "test5")))))))
  end

  it "group dependencies are applied" do
    flow = ATP::Program.new.flow(:sort1) 
    flow.test :test1
    flow.group "g1", id: :g1 do
      flow.test :test2
      flow.test :test3
    end
    flow.group "g2", conditions: { if_failed: :g1 } do
      flow.test :test4
      flow.test :test5
    end
    flow.ast.should ==
      s(:flow,
        s(:test,
          s(:object, "test1")),
        s(:group, 
          s(:name, "g1"),
          s(:id, :g1),
          s(:members,
            s(:test,
              s(:object, "test2")),
            s(:test,
              s(:object, "test3"))),
          s(:on_fail,
            s(:set_run_flag, "g1_FAILED"),
            s(:continue))),
        s(:run_flag, "g1_FAILED", true,
          s(:group, 
            s(:name, "g2"),
            s(:members,
              s(:test,
                s(:object, "test4")),
              s(:test,
                s(:object, "test5"))))))
  end
end