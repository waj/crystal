lib LibC
  alias SigT = Int32 ->

  ifdef darwin
    alias SigSetT = UInt32
  elsif linux
    alias SigSetT = UInt64[16]
  end

  fun sigemptyset(set : SigSetT*) : LibC::Int
  fun sigaddset(set : SigSetT*, signo : LibC::Int) : LibC::Int

  struct SigAction
    u : SigActionU
    sa_mask : SigSetT
    sa_flags : LibC::Int
  end

  union SigActionU
    sa_handler : LibC::Int -> Void
    sa_sigaction : LibC::Int, SigInfo*, Void* -> Void
  end

  ifdef darwin
    struct SigInfo
      si_signo : LibC::Int
      si_errno : LibC::Int
      si_code : LibC::Int
      si_pid : PidT
      si_uid : UidT
      si_status : LibC::Int
      si_addr : Void*
      si_value : SigVal
      si_band : LibC::Long
    end
  elsif linux
    struct SigInfo
      si_signo : Int
      si_errno : Int
      si_code : Int
      si : SigInfoSiFields
    end

    union SigInfoSiFields
      _pad : LibC::Int[28]
      kill : SigInfoSiFieldsKill
      timer : SigInfoSiFieldsTimer
      rt : SigInfoSiFieldsRt
      sigchld : SigInfoSiFieldsSigchld
      sigfault : SigInfoSiFieldsSigfault
      sigpoll : SigInfoSiFieldsSigpoll
      sigsys : SigInfoSiFieldsSigsys
    end

    struct SigInfoSiFieldsKill
      pid : PidT
      uid : UidT
    end

    struct SigInfoSiFieldsTimer
      tid : Int
      overrun : Int
      sigval : SigVal
    end

    struct SigInfoSiFieldsRt
      pid : PidT
      uid : UidT
      sigval : SigVal
    end

    struct SigInfoSiFieldsSigchld
      pid : PidT
      uid : UidT
      status : Int
      utime : ClockT
      stime : ClockT
    end

    struct SigInfoSiFieldsSigfault
      addr : Void*
      addr_lsb : Short
    end

    struct SigInfoSiFieldsSigpoll
      band : Long
      fd : Int
    end

    struct SigInfoSiFieldsSigsys
      call_addr : Void*
      syscall : Int
      arch : UInt
    end
  end

  union SigVal
    sival_int : LibC::Int
    sival_ptr : Void*
  end

  fun sigaction(sig : LibC::Int, act : SigAction*, oact : SigAction*) : LibC::Int
  fun sigprocmask(how : LibC::Int, set : SigSetT*, oset : SigSetT*) : LibC::Int

  ifdef darwin
    SIG_BLOCK   = 1
    SIG_UNBLOCK = 2
    SIG_SETMASK = 3
  elsif linux
    SIG_BLOCK   = 0
    SIG_UNBLOCK = 1
    SIG_SETMASK = 2
  end

  ifdef darwin
    struct StackT
      ss_sp : Void*
      ss_size : SizeT
      ss_flags : LibC::Int
    end
  elsif linux
    struct StackT
      ss_sp : Void*
      ss_flags : LibC::Int
      ss_size : SizeT
    end
  end

  fun sigaltstack(ss : StackT*, oss : StackT*) : LibC::Int

  ifdef darwin
    SA_ONSTACK   = 0x0001
    SA_RESTART   = 0x0002
    SA_RESETHAND = 0x0004
    SA_NOCLDSTOP = 0x0008
    SA_NODEFER   = 0x0010
    SA_NOCLDWAIT = 0x0020
    SA_SIGINFO   = 0x0040

    SS_ONSTACK = 0x0001
    SS_DISABLE = 0x0004

    MINSIGSTKSZ =  32768
    SIGSTKSZ    = 131072
  elsif linux
    SA_NOCLDSTOP = 0x00000001
    SA_NOCLDWAIT = 0x00000002
    SA_SIGINFO   = 0x00000004
    SA_ONSTACK   = 0x08000000
    SA_RESTART   = 0x10000000
    SA_NODEFER   = 0x40000000
    SA_RESETHAND = 0x80000000

    SS_ONSTACK = 1
    SS_DISABLE = 2

    MINSIGSTKSZ = 2048
    SIGSTKSZ    = 8192
  end

  fun signal(sig : Int, handler : SigT) : SigT
end

ifdef darwin
  enum Signal
    HUP    =  1
    INT    =  2
    QUIT   =  3
    ILL    =  4
    TRAP   =  5
    IOT    =  6
    ABRT   =  6
    EMT    =  7
    FPE    =  8
    KILL   =  9
    BUS    = 10
    SEGV   = 11
    SYS    = 12
    PIPE   = 13
    ALRM   = 15
    TERM   = 15
    URG    = 16
    STOP   = 17
    TSTP   = 18
    CONT   = 19
    CHLD   = 20
    CLD    = 20
    TTIN   = 21
    TTOU   = 22
    IO     = 23
    XCPU   = 24
    XFSZ   = 25
    VTALRM = 26
    PROF   = 27
    WINCH  = 28
    INFO   = 29
    USR1   = 30
    USR2   = 31
  end
else
  enum Signal
    HUP    =  1
    INT    =  2
    QUIT   =  3
    ILL    =  4
    TRAP   =  5
    ABRT   =  6
    IOT    =  6
    BUS    =  7
    FPE    =  8
    KILL   =  9
    USR1   = 10
    SEGV   = 11
    USR2   = 12
    PIPE   = 13
    ALRM   = 14
    TERM   = 15
    STKFLT = 16
    CLD    = 17
    CHLD   = 17
    CONT   = 18
    STOP   = 19
    TSTP   = 20
    TTIN   = 21
    TTOU   = 22
    URG    = 23
    XCPU   = 24
    XFSZ   = 25
    VTALRM = 26
    PROF   = 27
    WINCH  = 28
    POLL   = 29
    IO     = 29
    PWR    = 30
    SYS    = 31
    UNUSED = 31
  end
end

# Signals are processed through the event loop and run in their own Fiber.
# Signals may be lost if the event loop doesn't run before exit.
# An uncaught exceptions in a signal handler is a fatal error.
enum Signal
  def trap(block : Signal ->)
    trap &block
  end

  def trap(&block : Signal ->)
    Event::SignalHandler.add_handler self, block
  end

  def reset
    case self
    when CHLD
      # don't ignore by default.  send events to a waitpid service
      trap do
        Event::SignalChildHandler.instance.trigger
        nil
      end
    else
      del_handler Proc(Int32, Void).new(Pointer(Void).new(0_u64), Pointer(Void).null)
    end
  end

  def ignore
    del_handler Proc(Int32, Void).new(Pointer(Void).new(1_u64), Pointer(Void).null)
  end

  private def del_handler(block)
    Event::SignalHandler.del_handler self
    LibC.signal value, block
  end
end
