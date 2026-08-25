#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time





SIMULATE    = False
ZONE_SOURCE = "gpio"



PIN_GREEN, PIN_YELLOW, PIN_RED = 22, 27, 17
ZONE_FILE = os.path.expanduser("~/safety_arm/ZONE")
STOP_FILE = os.path.expanduser("~/safety_arm/STOP")

CTRL_HZ  = 50
DT       = 1.0 / CTRL_HZ
GRIP_DPS = 150.0


SAFE_START_DELAY = 0.6


CH = {"base": 0, "shoulder": 1, "elbow": 2, "wrist": 3, "roll": 4, "grip": 5}




SAFE_START_ORDER = ["grip", "shoulder", "elbow", "wrist", "roll", "base"]


HARD_LIMITS = {"base": (0, 180), "shoulder": (0, 120), "elbow": (0, 180),
               "wrist": (0, 180), "roll": (0, 180), "grip": (0, 180)}



SAFE_LIMITS = {"base": (0, 180),
               "shoulder": (0, 20),
               "elbow": (40, 180),
               "wrist": (110, 155),
               "roll": (170, 180),
               "grip": (0, 180)}




ROLL_WORK = 180

BASE_PICK, BASE_PLACE = 0, 180

GRIP_WIDE    = 0
GRIP_HOLD    = 180
GRIP_RELEASE = 120









def P(base, shoulder, elbow, wrist, grip):
    """자세 하나를 만든다. grip=None 이면 현재 집게 상태를 유지한다."""
    return {"base": base, "shoulder": shoulder, "elbow": elbow,
            "wrist": wrist, "roll": ROLL_WORK, "grip": grip}



POSE_ARRIVE_L   = P(BASE_PICK,   5,  45, 145, GRIP_WIDE)
POSE_PICK_OPEN  = P(BASE_PICK,   0, 180, 130, GRIP_WIDE)
POSE_PICK_HOLD  = P(BASE_PICK,   0, 180, 130, GRIP_HOLD)
POSE_CARRY_L    = P(BASE_PICK,   5,  45, 145, None)
POSE_CARRY_R    = P(BASE_PLACE,  5,  45, 145, None)
POSE_PLACE_HOLD = P(BASE_PLACE, 10, 134, 120, None)
POSE_PLACE_OPEN = P(BASE_PLACE, 10, 134, 120, GRIP_RELEASE)
POSE_BACK_UP    = P(BASE_PLACE,  5,  45, 145, None)


POSE_HOME = P(90, 5, 45, 145, GRIP_RELEASE)












SH_SAFE, EL_SAFE, WR_SAFE = 5, 45, 145


def resolve(pose, cur):
    """자세에서 None 인 항목을 현재 각도로 채운다."""
    return {j: (cur[j] if v is None else v) for j, v in pose.items()}


def legs_to(cur, target):
    """
    cur -> target 이동을 안전한 구간들로 분해한다.
      베이스가 바뀌면:  ① 제자리에서 안전 높이로  ② 회전만  ③ 목표 자세로
      베이스가 같으면:  목표 자세로 바로
    집게는 이동 중에 건드리지 않고 마지막 구간에서만 바꾼다.
    """
    if abs(target["base"] - cur["base"]) < 0.5:
        return [("", target)]

    lift = dict(cur)
    lift.update(shoulder=SH_SAFE, elbow=EL_SAFE, wrist=WR_SAFE)
    rot = dict(lift)
    rot["base"] = target["base"]
    return [(" (안전높이)", lift), (" (회전)", rot), (" (자세맞춤)", target)]





Z_SAFE, Z_SLOW, Z_STOP = 0, 1, 2


ZONE_PROFILE = {
    Z_SAFE: {"name": "SAFE",    "speed": 35.0, "pause": 0.3},
    Z_SLOW: {"name": "CAUTION", "speed": 20.0, "pause": 0.3},
}


def build_cycle():
    """
    픽앤플레이스 1사이클. 각 항목은 (설명, 자세, 도착 후 정지 여부) 이다.
    구역과 무관하게 항상 같은 사이클을 돈다. 구역은 속도만 바꾼다.

    ★ 경로 설계 원칙
      · 베이스 회전은 반드시 '안전 높이(어깨 5 / 팔꿈치 45)'에서만 한다.
      · 오르내림은 반드시 '제자리(베이스 고정)'에서만 한다.
      두 동작이 겹치면 팔이 대각선으로 쓸고 지나가면서
      라이다 보호영역을 스스로 침범한다. (실측으로 확인된 문제)
      이 원칙은 legs_to() 가 모든 이동에 자동으로 적용한다.

    ★ stop=False 인 단계는 경유점이므로 멈추지 않고 그대로 통과한다.
    """
    return [
        ("1 왼쪽으로 복귀",   POSE_ARRIVE_L,   False),
        ("2 집으러 내려가기", POSE_PICK_OPEN,  True),
        ("3 집기",            POSE_PICK_HOLD,  True),
        ("4 들어올리기",      POSE_CARRY_L,    False),
        ("5 오른쪽으로 운반", POSE_CARRY_R,    False),
        ("6 놓을 위치로",     POSE_PLACE_HOLD, True),
        ("7 놓기",            POSE_PLACE_OPEN, True),
        ("8 제자리에서 들기", POSE_BACK_UP,    False),
    ]


PRINT_EVERY = 25





class SimServo:
    def __init__(self):
        self.angle = dict(POSE_HOME)

    def write(self, joint, ang):
        self.angle[joint] = ang

    def dump(self):
        return "  ".join(f"{j[:2]}={self.angle[j]:5.1f}" for j in CH)

    def safe_start(self):
        print("[시작] (시뮬) HOME 자세 가정")


class RealServo:
    """
    실제 PCA9685.
    값이 실질적으로 안 바뀐 관절은 I2C 전송을 생략해 버스 부하를 줄인다.
    (50Hz x 6관절 = 초당 300전송은 100kHz I2C 에 부담이 된다)
    """
    WRITE_EPS = 0.2

    def __init__(self):
        from adafruit_servokit import ServoKit
        self.kit = ServoKit(channels=16)
        self.angle = dict(POSE_HOME)
        self._sent = {}
        self.skipped = 0
        self.written = 0

    def write(self, joint, ang):
        self.angle[joint] = ang
        last = self._sent.get(joint)
        if last is not None and abs(ang - last) < self.WRITE_EPS:
            self.skipped += 1
            return
        self.kit.servo[CH[joint]].angle = ang
        self._sent[joint] = ang
        self.written += 1

    def dump(self):
        return "  ".join(f"{j[:2]}={self.angle[j]:5.1f}" for j in CH)

    def safe_start(self):
        """
        전원 인가 직후 팔이 어느 자세인지 알 수 없다.
        관절을 '하나씩' HOME 으로 보내 예측 가능하게 만든다.
        여러 관절을 동시에 움직이면 경로를 예측할 수 없어 위험하다.
        """
        print("[시작] 안전 시작 루틴 — 관절을 하나씩 HOME 으로 이동합니다.")
        print("       팔에서 손을 떼고, 전원 스위치에 손을 올려두세요.")
        for j in SAFE_START_ORDER:
            ang = POSE_HOME[j]
            print(f"       {j:<9s} -> {ang:3.0f}도")
            self.kit.servo[CH[j]].angle = ang
            self._sent[j] = ang
            self.angle[j] = ang
            time.sleep(SAFE_START_DELAY)
        print("[시작] HOME 도달.\n")





class ZoneFile:
    def __init__(self):
        print("[ZONE] 파일 감시 모드")
        print("       SAFE   : rm ~/safety_arm/ZONE")
        print("       CAUTION: echo 1 > ~/safety_arm/ZONE")
        print("       DANGER : echo 2 > ~/safety_arm/ZONE   (또는 touch STOP)")

    def zone(self):
        if os.path.exists(STOP_FILE):
            return Z_STOP
        try:
            with open(ZONE_FILE) as f:
                v = int(f.read().strip())
            return v if v in (Z_SAFE, Z_SLOW, Z_STOP) else Z_SAFE
        except Exception:
            return Z_SAFE

    def close(self):
        pass


class ZoneGpio:
    def __init__(self):
        from gpiozero import DigitalInputDevice
        self.g = DigitalInputDevice(PIN_GREEN,  pull_up=False)
        self.y = DigitalInputDevice(PIN_YELLOW, pull_up=False)
        self.r = DigitalInputDevice(PIN_RED,    pull_up=False)
        print(f"[ZONE] GPIO 모드  녹={PIN_GREEN} 황={PIN_YELLOW} 적={PIN_RED}")

    def zone(self):
        if self.r.value:
            return Z_STOP
        if self.y.value:
            return Z_SLOW
        if self.g.value:
            return Z_SAFE
        return Z_STOP

    def close(self):
        for d in (self.g, self.y, self.r):
            d.close()





def check_pose(pose, label):
    for j, ang in pose.items():
        if ang is None:
            continue
        hl, hh = HARD_LIMITS[j]
        sl, sh = SAFE_LIMITS[j]
        if not (hl <= ang <= hh):
            raise ValueError(f"[{label}] {j}={ang} 가 기계한계 {hl}~{hh} 밖")
        if not (sl <= ang <= sh):
            raise ValueError(f"[{label}] {j}={ang} 가 작업한계 {sl}~{sh} 밖")


def check_all_poses():
    check_pose(POSE_HOME, "HOME")
    n = 1
    for label, pose, _stop in build_cycle():
        check_pose(pose, label)
        n += 1
    print(f"[안전] 자세 {n}개 전부 안전범위 통과")





DONE, STOPPED, ZONE_CHANGED = "DONE", "STOPPED", "ZONE_CHANGED"


class Arm:
    def __init__(self, servo, zoner):
        self.sv = servo
        self.zoner = zoner
        self.freeze_count = 0
        self.slow_warned = False

    def move_to(self, target, label, speed, watch_zone=None, quiet=False):
        cur = dict(self.sv.angle)
        target = resolve(target, cur)
        steps = 1
        for j, tgt in target.items():
            dps = GRIP_DPS if j == "grip" else speed
            steps = max(steps, int(abs(tgt - cur[j]) / dps / DT))

        t_loop = time.time()
        for i in range(1, steps + 1):

            z = self.zoner.zone()
            if z == Z_STOP:
                return STOPPED
            if watch_zone is not None and z != watch_zone:
                return ZONE_CHANGED

            for j, tgt in target.items():
                a = cur[j] + (tgt - cur[j]) * i / steps
                lo, hi = SAFE_LIMITS[j]
                self.sv.write(j, max(lo, min(hi, a)))

            if not quiet and i % PRINT_EVERY == 0:
                print(f"    {label:<20s} {self.sv.dump()}")


            elapsed = time.time() - t_loop
            if elapsed < DT:
                time.sleep(DT - elapsed)
            elif not self.slow_warned and elapsed > DT * 2:
                print(f"    [경고] 루프 지연 {elapsed*1000:.0f}ms "
                      f"(목표 {DT*1000:.0f}ms). I2C 속도를 확인하세요.")
                self.slow_warned = True
            t_loop = time.time()

        return DONE

    def move_safely(self, target, label, speed, watch_zone=None):
        """
        어떤 자세에서든 목표까지 안전하게 이동한다.
        legs_to() 로 회전/승강을 분리하므로 대각선 궤적이 생기지 않는다.
        구역 전환 직후처럼 팔이 어디에 있을지 모르는 상황에서도 안전하다.
        """
        cur = dict(self.sv.angle)
        tgt = resolve(target, cur)
        for suffix, leg in legs_to(cur, tgt):
            r = self.move_to(leg, label + suffix, speed, watch_zone)
            if r != DONE:
                return r
        return DONE

    def hold(self, seconds, watch_zone):
        t_end = time.time() + seconds
        while time.time() < t_end:
            z = self.zoner.zone()
            if z == Z_STOP:
                return STOPPED
            if z != watch_zone:
                return ZONE_CHANGED
            time.sleep(DT)
        return DONE

    def freeze_and_wait(self):
        self.freeze_count += 1
        t0 = time.time()
        print("\n" + "=" * 62)
        print(f"  [FROZEN #{self.freeze_count}]  현재 자세 유지")
        print(f"    {self.sv.dump()}")
        print("    PCA9685 가 마지막 PWM 유지 -> 팔은 낙하하지 않음")
        print("=" * 62)

        while self.zoner.zone() == Z_STOP:
            time.sleep(DT)

        print(f"  -> 해제. {time.time()-t0:.1f}초간 정지 유지. 동작 재개.\n")





def build(zoner=None):
    servo = SimServo() if SIMULATE else RealServo()
    if zoner is None:
        zoner = ZoneFile() if ZONE_SOURCE == "file" else ZoneGpio()
    return Arm(servo, zoner)


def banner():
    print("=" * 62)
    print(f"  safety_arm v3  |  SIMULATE={SIMULATE}  ZONE_SOURCE={ZONE_SOURCE}")
    print(f"  제어주기 {CTRL_HZ}Hz (1스텝 {DT*1000:.0f}ms)")
    if not SIMULATE:
        print("  ! 실제 서보가 움직입니다. 팔 주변을 비우고 전원에 손을 두세요.")
    print("=" * 62)


def run_normal(arm=None, max_cycles=None):
    if arm is None:
        banner()
        check_all_poses()
        arm = build()

    cycles = 0
    last_zone = None
    cycle = build_cycle()
    step = 0

    try:
        arm.sv.safe_start()

        print("[운전] 시작. Ctrl+C 로 종료.\n")
        while True:
            z = arm.zoner.zone()
            if z == Z_STOP:
                arm.freeze_and_wait()
                continue

            p = ZONE_PROFILE[z]

            if z != last_zone:
                print(f"\n  ### 구역 = {p['name']}  |  속도 {p['speed']:.0f}도/초"
                      f"  |  하던 작업을 그대로 계속합니다\n")
                last_zone = z

            label, pose, stop_here = cycle[step]
            print(f"  > {label}")

            r = arm.move_safely(pose, label, p["speed"], watch_zone=z)
            if r == STOPPED:
                arm.freeze_and_wait()
                continue
            if r == ZONE_CHANGED:

                print("    (구역 변경 -> 속도 변경 후 이어서 진행)")
                continue
            if stop_here and arm.hold(p["pause"], z) != DONE:
                continue

            step += 1
            if step >= len(cycle):
                step = 0
                cycles += 1
                extra = ""
                if hasattr(arm.sv, "written"):
                    tot = arm.sv.written + arm.sv.skipped
                    if tot:
                        extra = f", I2C 전송 {arm.sv.written}/{tot}회"
                print(f"  --- 사이클 {cycles}회 완료 "
                      f"(정지 {arm.freeze_count}회{extra}) ---\n")
                if max_cycles and cycles >= max_cycles:
                    return

    except KeyboardInterrupt:
        print(f"\n\n[종료] 사이클 {cycles}회, 정지 {arm.freeze_count}회")
        print("      마지막 자세를 유지한 채 종료합니다.")
    finally:
        arm.zoner.close()


def run_home():
    banner()
    arm = build()
    check_pose(POSE_HOME, "HOME")
    arm.sv.safe_start()
    print("[HOME]", arm.sv.dump())
    arm.zoner.close()


def run_servo_check():
    """
    서보 단독 확인. 구역과 무관하게, 베이스만 아주 좁게 왕복한다.
    PCA9685 제어가 실제로 먹히는지 최소 동작으로 확인하는 용도.
    """
    banner()
    if SIMULATE:
        print("[확인] SIMULATE=True 라 실제 서보는 움직이지 않습니다.")
    servo = SimServo() if SIMULATE else RealServo()
    servo.safe_start()

    print("[확인] 베이스를 80 <-> 100 도 사이에서 3회 왕복합니다. Ctrl+C 로 중단.")
    try:
        cur = POSE_HOME["base"]
        for n in range(3):
            for tgt in (80, 100, 90):
                steps = max(1, int(abs(tgt - cur) / 20.0 / DT))
                for i in range(1, steps + 1):
                    servo.write("base", cur + (tgt - cur) * i / steps)
                    time.sleep(DT)
                cur = tgt
                print(f"   {n+1}회차  base -> {tgt}도")
                time.sleep(0.4)
        print("\n[확인] 완료. 팔이 부드럽게 움직였다면 정상입니다.")
    except KeyboardInterrupt:
        print("\n[확인] 중단됨.")





class FakeZone:
    def __init__(self):
        self.v = Z_SAFE

    def zone(self):
        return self.v

    def close(self):
        pass


def run_latency():
    import threading
    print("[측정] 정지 응답시간 테스트\n")
    fz = FakeZone()
    arm = Arm(SimServo(), fz)
    results = []

    for n in range(5):
        arm.sv.angle = dict(POSE_HOME)
        fz.v = Z_SAFE
        target = POSE_CARRY_R
        delay = 0.5 + n * 0.03
        t_trip = [None]

        def trip():
            time.sleep(delay)
            t_trip[0] = time.time()
            fz.v = Z_STOP

        threading.Thread(target=trip, daemon=True).start()
        r = arm.move_to(target, "test", 35.0, quiet=True)
        t_stop = time.time()
        if r == STOPPED and t_trip[0]:
            lat = (t_stop - t_trip[0]) * 1000.0
            results.append(lat)
            print(f"  {n+1}회: 정지 -> 명령중단까지 {lat:6.1f} ms")
        else:
            print(f"  {n+1}회: 측정 실패")

    if results:
        print(f"\n  최악 {max(results):.1f} ms / 평균 {sum(results)/len(results):.1f} ms")
        print(f"  이론 최악값 = 1스텝 = {DT*1000:.0f} ms")
        print("  사람 손 접근속도 1.6m/s 기준, 20ms 동안 이동거리 = 3.2cm")


def run_demo():
    import threading
    print("[시연] SAFE -> CAUTION -> DANGER -> SAFE 자동 전환\n")
    fz = FakeZone()
    arm = build(zoner=fz)

    def script():
        for wait, z, msg in [(14, Z_SLOW, "사람이 접근 -> 주의구역"),
                             (14, Z_STOP, "더 접근 -> 위험구역"),
                             (5,  Z_SAFE, "사람이 물러남 -> 안전구역"),
                             (10, None,   "시연 종료")]:
            time.sleep(wait)
            if z is None:
                print("\n[시연 종료]")
                os._exit(0)
            print(f"\n  >>> {msg} <<<")
            fz.v = z

    threading.Thread(target=script, daemon=True).start()
    run_normal(arm=arm)


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "run"
    if arg == "home":
        run_home()
    elif arg == "servo":
        run_servo_check()
    elif arg == "latency":
        run_latency()
    elif arg == "demo":
        run_demo()
    else:
        run_normal()
