require "../safe_int_spec_helper"

# Ported from https://github.com/dcleblanc/SafeInt/blob/3.23/Test/AddVerify.cpp#L4545-L4633
run_add_tests UInt8, UInt16, [
  {0x00, 0x0000, true},
  {0x01, 0x0000, true},
  {0x02, 0x0000, true},
  {0x7e, 0x0000, true},
  {0x7f, 0x0000, true},
  {0x80, 0x0000, true},
  {0x81, 0x0000, true},
  {0xfe, 0x0000, true},
  {0xff, 0x0000, true},

  {0x00, 0x0001, true},
  {0x01, 0x0001, true},
  {0x02, 0x0001, true},
  {0x7e, 0x0001, true},
  {0x7f, 0x0001, true},
  {0x80, 0x0001, true},
  {0x81, 0x0001, true},
  {0xfe, 0x0001, true},
  {0xff, 0x0001, false},

  {0x00, 0x0002, true},
  {0x01, 0x0002, true},
  {0x02, 0x0002, true},
  {0x7e, 0x0002, true},
  {0x7f, 0x0002, true},
  {0x80, 0x0002, true},
  {0x81, 0x0002, true},
  {0xfe, 0x0002, false},
  {0xff, 0x0002, false},

  {0x00, 0x7ffe, false},
  {0x01, 0x7ffe, false},
  {0x02, 0x7ffe, false},
  {0x7e, 0x7ffe, false},
  {0x7f, 0x7ffe, false},
  {0x80, 0x7ffe, false},
  {0x81, 0x7ffe, false},
  {0xfe, 0x7ffe, false},
  {0xff, 0x7ffe, false},

  {0x00, 0x7fff, false},
  {0x01, 0x7fff, false},
  {0x02, 0x7fff, false},
  {0x7e, 0x7fff, false},
  {0x7f, 0x7fff, false},
  {0x80, 0x7fff, false},
  {0x81, 0x7fff, false},
  {0xfe, 0x7fff, false},
  {0xff, 0x7fff, false},

  {0x00, 0x8000, false},
  {0x01, 0x8000, false},
  {0x02, 0x8000, false},
  {0x7e, 0x8000, false},
  {0x7f, 0x8000, false},
  {0x80, 0x8000, false},
  {0x81, 0x8000, false},
  {0xfe, 0x8000, false},
  {0xff, 0x8000, false},

  {0x00, 0x8001, false},
  {0x01, 0x8001, false},
  {0x02, 0x8001, false},
  {0x7e, 0x8001, false},
  {0x7f, 0x8001, false},
  {0x80, 0x8001, false},
  {0x81, 0x8001, false},
  {0xfe, 0x8001, false},
  {0xff, 0x8001, false},

  {0x00, 0xfffe, false},
  {0x01, 0xfffe, false},
  {0x02, 0xfffe, false},
  {0x7e, 0xfffe, false},
  {0x7f, 0xfffe, false},
  {0x80, 0xfffe, false},
  {0x81, 0xfffe, false},
  {0xfe, 0xfffe, false},
  {0xff, 0xfffe, false},

  {0x00, 0xffff, false},
  {0x01, 0xffff, false},
  {0x02, 0xffff, false},
  {0x7e, 0xffff, false},
  {0x7f, 0xffff, false},
  {0x80, 0xffff, false},
  {0x81, 0xffff, false},
  {0xfe, 0xffff, false},
  {0xff, 0xffff, false},
]
