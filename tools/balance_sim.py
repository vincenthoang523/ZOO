"""Draw a Zoo - progression simulator. Mirrors Config.luau + ZooServer.server.luau to estimate how long an active
player needs to be fully maxed (luck 10/10 and capacity 12/12), with and without the game passes.

Player model (the assumptions every number depends on):
  - draws one animal every DRAW_SECONDS of play (the server allows one per 5 s; a real drawing takes far longer)
  - the judge's stars follow STAR_ODDS (a decent, not perfect, artist)
  - keeps the best `capacity` animals equipped and sells every other drawing to Safari Sam straight away
  - buys whichever upgrade is cheaper the moment it can afford it
  - ignores daily rewards, offline earnings and dev products (boosts, starter pack)
Run:  python tools/balance_sim.py
"""
import random, statistics

# ---- mirrors Config.luau ----
RARITIES = [(1, 10), (4, 40), (16, 150), (64, 600), (256, 2500), (1024, 10000)]   # (oneIn, rate)
MUTATIONS = [(0.9, 1), (0.06, 3), (0.03, 6), (0.01, 15)]
STAR_MULT = [1, 1.5, 2.5, 4, 6]
BASE_RATE, SELL_SECONDS = 10, 30
MAX_LUCK, CAP_START, CAP_MAX = 10, 2, 12

DRAW_SECONDS = 45
STAR_ODDS = [(1, 0.05), (2, 0.2), (3, 0.45), (4, 0.25), (5, 0.05)]


def chances(luck):
    out, remaining = [0] * len(RARITIES), 1.0
    for i in range(len(RARITIES) - 1, -1, -1):
        p = min(1, luck / RARITIES[i][0]) * remaining
        out[i] = p
        remaining -= p
    return out


def pick(rng, weights):
    r = rng.random()
    for i, w in enumerate(weights):
        r -= w
        if r < 0: return i
    return len(weights) - 1


def draw_income(rng, luck):
    r = pick(rng, chances(luck))
    m = pick(rng, [c for c, _ in MUTATIONS])
    s = pick(rng, [w for _, w in STAR_ODDS])
    return int(BASE_RATE * STAR_MULT[s] * (RARITIES[r][1] / BASE_RATE) * MUTATIONS[m][1])


def time_to_max(luck_cost, cap_cost, passes=False, seed=0):
    rng = random.Random(seed)
    cash, luck_lv, cap_lv, t = 0.0, 0, 0, 0
    equipped = []                                        # incomes of equipped animals
    money_mult = (2 * 1.2) if passes else 1              # Money2x and VIP
    while luck_lv < MAX_LUCK or CAP_START + cap_lv < CAP_MAX:
        cap = min(CAP_MAX, CAP_START + cap_lv)
        luck = 2 ** luck_lv * (2 if passes else 1)       # Luck2x
        inc = draw_income(rng, luck)
        equipped.append(inc)
        equipped.sort(reverse=True)
        while len(equipped) > cap:                       # sell the worst
            cash += equipped.pop() * SELL_SECONDS
        rate = int(sum(equipped) * money_mult)
        for _ in range(DRAW_SECONDS):                    # a second at a time, buying as soon as affordable
            cash += rate
            t += 1
            while True:
                opts = []
                if luck_lv < MAX_LUCK: opts.append((luck_cost(luck_lv), "luck"))
                if CAP_START + cap_lv < CAP_MAX: opts.append((cap_cost(cap_lv), "cap"))
                if not opts: break
                cost, kind = min(opts)
                if cash < cost: break
                cash -= cost
                if kind == "luck": luck_lv += 1
                else: cap_lv += 1
        if t > 400 * 3600: return float("inf")
    return t


def time_to_upgrades(luck_cost, cap_cost, seed, minutes=30):
    """(luck, size) levels a no-pass player has bought after `minutes` of play."""
    rng = random.Random(seed)
    cash, luck_lv, cap_lv, t, equipped = 0.0, 0, 0, 0, []
    while t < minutes * 60:
        cap = CAP_START + cap_lv
        equipped.append(draw_income(rng, 2 ** luck_lv)); equipped.sort(reverse=True)
        while len(equipped) > cap: cash += equipped.pop() * SELL_SECONDS
        rate = sum(equipped)
        for _ in range(DRAW_SECONDS):
            cash += rate; t += 1
            while True:
                opts = []
                if luck_lv < MAX_LUCK: opts.append((luck_cost(luck_lv), "luck"))
                if CAP_START + cap_lv < CAP_MAX: opts.append((cap_cost(cap_lv), "cap"))
                if not opts: break
                cost, kind = min(opts)
                if cash < cost: break
                cash -= cost
                if kind == "luck": luck_lv += 1
                else: cap_lv += 1
    return luck_lv, cap_lv


def report(name, luck_cost, cap_cost, runs=40):
    for passes in (False, True):
        hrs = [time_to_max(luck_cost, cap_cost, passes, seed) / 3600 for seed in range(runs)]
        print(f"{name:8s} {'all passes' if passes else 'no passes ':10s} median {statistics.median(hrs):6.2f} h"
              f"   (10th-90th pct {sorted(hrs)[runs // 10]:.2f}-{sorted(hrs)[runs * 9 // 10]:.2f} h)")


ORDER = ["cap", "luck"] * 10        # intended upgrade order: alternate, capacity first


def schedule(first_min=1.0, early=11, early_min=30.0, total_hours=24.0):
    """Minute each upgrade lands at: geometric (every gap a fixed factor longer) from first_min to early_min for the
    first `early` upgrades (retention: 6 size + 5 luck in the first half hour), then a steeper geometric to total_hours."""
    g1 = (early_min / first_min) ** (1 / (early - 1))
    g2 = (total_hours * 60 / early_min) ** (1 / (len(ORDER) - early))
    return [first_min * g1 ** i if i < early else early_min * g2 ** (i - early + 1) for i in range(len(ORDER))]


def fit(runs=40):
    """Cost of each upgrade so that, bought in ORDER, upgrade i lands at schedule()[i]. The cost is the median cash a
    player has made since the previous upgrade, so they can afford it right on schedule."""
    targets = [m * 60 for m in schedule()]
    costs = []
    for i, target in enumerate(targets):
        made = []
        for seed in range(runs):
            rng = random.Random(seed)
            luck_lv = cap_lv = t = 0
            done, cash, equipped = 0, 0.0, []
            while t < target:
                cap = min(CAP_MAX, CAP_START + cap_lv)
                equipped.append(draw_income(rng, 2 ** luck_lv)); equipped.sort(reverse=True)
                while len(equipped) > cap: cash += equipped.pop() * SELL_SECONDS
                rate = sum(equipped)
                for _ in range(DRAW_SECONDS):
                    t += 1; cash += rate
                    if done < i and t >= targets[done]:          # earlier upgrades happen on schedule
                        cash -= costs[done]
                        if ORDER[done] == "luck": luck_lv += 1
                        else: cap_lv += 1
                        done += 1
                    if t >= target: break
            made.append(cash)
        costs.append(max(100, statistics.median(made)))   # median: a few lucky Mythic rolls must not set the price
    return costs


def nice(n):
    """Round to 2 significant figures so prices read cleanly ($1.4M, not $1,387,215)."""
    import math
    p = 10 ** max(0, int(math.floor(math.log10(n))) - 1)
    return int(round(n / p) * p)


if __name__ == "__main__":
    assert abs(sum(chances(1)) - 1) < 1e-9 and chances(1024)[-1] == 1   # self-check: odds always sum to 1
    report("current", lambda l: 500 * 4 ** l, lambda l: 300 * 3 ** l)
    costs = [nice(c) for c in fit()]
    luck = [c for c, k in zip(costs, ORDER) if k == "luck"]
    cap = [c for c, k in zip(costs, ORDER) if k == "cap"]
    print("LUCK_COSTS =", luck)
    print("CAP_COSTS  =", cap)
    report("fitted", lambda l: luck[l], lambda l: cap[l])
    first = [time_to_upgrades(lambda l: luck[l], lambda l: cap[l], seed) for seed in range(40)]
    print("upgrades in the first 30 min (luck, size): median", statistics.median(f[0] for f in first), statistics.median(f[1] for f in first))
