## =====================================================================
##  zybo_z7_pmod_v2.xdc  --  safety_axi Make External ?¬?Š¸?š© (Pmod JC)
## =====================================================================
##  ?˜… Make External ë¡? ?ƒê¸? ?¬?Š¸ ?´ë¦„ì— _0 ? ‘ë¯¸ì‚¬ê°? ë¶™ì–´?ˆ?Œ.
##    ë¸”ë¡?””??¸?˜ ?‹¤? œ ?™¸ë¶? ?¬?Š¸ ?´ë¦„ê³¼ ? •?™•?ˆ ?¼ì¹˜í•´?•¼ ?•¨.
##  ?? ë²ˆí˜¸: Zybo Z7 (Rev B) ê³µì‹ Master XDC?˜ Pmod JC ê¸°ì?.
## =====================================================================

## ---- ì¶œë ¥ (FPGA -> ?™¸ë¶?, MOSFET/ë¦´ë ˆ?´/LED ê²½ìœ ) ----
## JC1 : ë¦´ë ˆ?´ enable
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports { relay_en_pin_0 }];
## JC2 : ?Œ¬ PWM
set_property -dict { PACKAGE_PIN T11  IOSTANDARD LVCMOS33 } [get_ports { fan_pwm_pin_0 }];
## JC7 : LED ?…¹
set_property -dict { PACKAGE_PIN W15  IOSTANDARD LVCMOS33 } [get_ports { led_g_pin_0 }];
## JC8 : LED ?™©
set_property -dict { PACKAGE_PIN T10  IOSTANDARD LVCMOS33 } [get_ports { led_y_pin_0 }];
## JC9 : LED ? 
set_property -dict { PACKAGE_PIN Y14  IOSTANDARD LVCMOS33 } [get_ports { led_r_pin_0 }];
## JC10 : ë¶???
set_property -dict { PACKAGE_PIN U12  IOSTANDARD LVCMOS33 } [get_ports { buzzer_pin_0 }];

## ---- ?…? ¥ (?™¸ë¶? -> FPGA) ----
## JC3 : E-stop (NC). ? •?ƒ=HIGH ?˜?„ë¡? ë°°ì„ .
set_property -dict { PACKAGE_PIN W14  IOSTANDARD LVCMOS33 } [get_ports { estop_raw_pin_0 }];
## JC4 : Reset ë²„íŠ¼ (?ˆŒë¦?=HIGH)
set_property -dict { PACKAGE_PIN T12  IOSTANDARD LVCMOS33 } [get_ports { reset_btn_pin_0 }];
## ÀÔ·Â ÇÉ floating ¹æÁö (¾È ²ÈÇûÀ» ¶§ ¾ÈÀüÇÑ ±âº»°ª)
set_property PULLUP   true [get_ports { estop_raw_pin_0 }];
set_property PULLDOWN true [get_ports { reset_btn_pin_0 }];

## =====================================================================
##  I©÷C (¼¾¼­ VL53L5CX¿ë) - Pmod JD
## =====================================================================
## JD Pin 1 (T14) = SCL,  JD Pin 2 (T15) = SDA
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 PULLUP true } [get_ports IIC_1_0_scl_io];
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 PULLUP true } [get_ports IIC_1_0_sda_io];
set_property -dict { PACKAGE_PIN P14  IOSTANDARD LVCMOS33  PULLDOWN true } [get_ports brake_en_pin_0];##  ì£¼ì˜:
##   - ?œ„ ?¬?Š¸ ?´ë¦?(_0)?´ ?‹¤? œ?? ?‹¤ë¥´ë©´ (?˜ˆ: _1 ?˜?Š” ? ‘ë¯¸ì‚¬ ?—†?Œ),
##     Vivado?—?„œ ?—?Ÿ¬ê°? ?‚œ?‹¤. ê·? ê²½ìš° ?‹¤? œ ?¬?Š¸ ?´ë¦„ìœ¼ë¡? ?ˆ˜? •?•  ê²?.
##     ë¸”ë¡?””??¸ ìº”ë²„?Š¤?—?„œ ?™¸ë¶? ?¬?Š¸(?™”?‚´?‘œ) ?´ë¦„ì„ ?™•?¸.
##   - E-stop(estop_raw)?? ? •?ƒ ?‹œ HIGH?—¬?•¼ ?•˜ë¯?ë¡?, NC? ‘? ?„ 3.3V?— ?—°ê²°í•˜ê³?
##     ???— ???‹¤?š´(?™¸ë¶? 10k ?˜?Š” ?•„?˜ PULLDOWN). ì§?ê¸ˆì? ë°°ì„ ?—?„œ ì²˜ë¦¬ ê°?? •.
##   - ë¯¸ì‚¬?š© ?…? ¥ ë¶??œ  ë°©ì?ë¥? ?œ„?•´ estop/reset?— ?‚´ë¶? ?? ?„¤? • ê¶Œì¥:
## set_property PULLDOWN true [get_ports { estop_raw_pin_0 }];
## set_property PULLDOWN true [get_ports { reset_btn_pin_0 }];
