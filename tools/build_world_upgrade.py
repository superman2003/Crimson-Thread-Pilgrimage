#!/usr/bin/env python3
"""Author optional action workshops and later-region branches in world overlay.

Standalone chapter data is intentionally untouched. Re-running replaces only
objects bearing this generator's upgrade_ prefix and keeps prior overlay work.
"""
import json
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'godot/data'
PATH = DATA / 'world_routes.json'
PREFIX = 'upgrade_'
REGIONS = [
    'demo_ch01_moss_bell_court', 'demo_ch02_rain_foundry_canal',
    'demo_ch03_saltwhite_archive', 'demo_ch04_broken_string_greenhouse',
    'demo_ch05_obsidian_pilgrim_road', 'demo_ch06_silent_crown_core',
]
ABILITIES = {
    'thread_dash': ('绯线冲刺', 'Shift 冲刺拨开计时栅闩。'),
    'silk_wall_grip': ('丝壁攀附', '贴住门壁按跳跃，墙跳拨开检修闩。'),
    'echo_hook': ('回声钩索', '在门前按 K 钩住铜环，牵引检修闩。'),
    'double_thread_jump': ('双线跃', '在门前腾空，再按一次跳跃，接通双线锁。'),
    'bell_guard': ('钟壳格挡', '在门前按 Q，钟壳震动拨开封蜡闩。'),
    'thorn_downstrike': ('棘线下劈', '站上裂纹封板，跳起后按下方向 + 攻击，下劈破开。'),
    'lantern_phase': ('灯影相位', '靠近门闩长按 E；消耗能量启动相位，拨开机械门闩。'),
    'crown_resonance': ('王冠共鸣', '靠近旧钟门按 R，消耗能量重接契约锁。'),
}
MOVEMENT_COMBOS = {
    'thread_dash': ['approach', 'dash_through_gate'],
    'silk_wall_grip': ['jump_to_wall', 'wall_grip', 'wall_jump'],
    'echo_hook': ['target_ring', 'hook_pull', 'land_beyond_gate'],
    'double_thread_jump': ['jump', 'air_jump', 'clear_gate'],
    'bell_guard': ['approach', 'bell_guard_pulse'],
    'thorn_downstrike': ['jump', 'down_attack', 'drop_through_seal'],
    'lantern_phase': ['approach', 'hold_phase'],
    'crown_resonance': ['approach', 'resonate'],
}
# Each gate sits at a distinct, walkable point in the room. These offsets leave
# a clear approach from the portal landing and retain enough room to act.
GATE_OFFSETS = {
    'thread_dash': 280, 'silk_wall_grip': 290, 'echo_hook': 300,
    'double_thread_jump': 310, 'bell_guard': 320, 'thorn_downstrike': 318,
    'lantern_phase': 330, 'crown_resonance': 340,
}
# Two actual old-area targets per ability, with different physical source rooms.
# platform IDs keep entrances on supported, existing ground, away from hazards.
TARGETS = {
    'thread_dash': [(1, 'first_bell_shrine', 'shrine_floor', 1630, '排水计时闸'), (2, 'silt_vault', 'sv_floor', 4240, '淤泥排压室')],
    'silk_wall_grip': [(1, 'threadmakers_cache', 'cache_floor', 1600, '纺线检修仓'), (2, 'pump_atrium', 'hub_floor_w', 2870, '泵房上检修舱')],
    'echo_hook': [(1, 'east_balcony', 'eb_floor', 4580, '钟骨吊运台'), (3, 'mezz_reading_ledges', 'mezz_gallery_floor', 1990, '运书吊篮仓')],
    'double_thread_jump': [(1, 'belfry_top', 'belfry_floor', 3140, '钟冠双线仓'), (2, 'riser_shrine', 'rs_floor', 1470, '双层水位记录室')],
    'bell_guard': [(1, 'bell_marrow_cell', 'cell_floor', 4030, '钟髓封蜡室'), (2, 'atrium_west_vault', 'vault_floor', 2200, '旧铸工证物柜')],
    'thorn_downstrike': [(1, 'root_vault', 'rv_floor', 2840, '棘根深井'), (3, 'salt_gate_walk', 'sg_run_a', 3250, '盐脊碎板井')],
    'lantern_phase': [(2, 'tide_listening_cell', 'tide_floor', 1760, '潮影检修室'), (4, 'beeswax_nook', 'bw_floor', 5070, '蜂蜡影闩室')],
    'crown_resonance': [(1, 'crown_treasury', 'ct_floor', 6600, '无名钟契库'), (3, 'secret_nook', 'nook_floor', 1490, '删名契约暗柜')],
}
EVIDENCE = {
    'thread_dash': ['计时闸检修签', '淤泥排压账'],
    'silk_wall_grip': ['纺线工回收令', '上泵房调度单'],
    'echo_hook': ['钟骨吊运清单', '运书吊篮收据'],
    'double_thread_jump': ['双线仓旧线轴', '两次涨潮的记录'],
    'bell_guard': ['封蜡中的求救声', '旧铸工拒签信'],
    'thorn_downstrike': ['棘根底部的铭牌', '碎板下的删改页'],
    'lantern_phase': ['潮影中的轮班表', '蜂蜡影闩密令'],
    'crown_resonance': ['无名者旧契约', '第七签署者反证'],
}


def build():
    routes = json.loads(PATH.read_text())
    chapters = routes['chapters']
    previous_rooms = {(region, room['id']): deepcopy(room)
                      for region, overlay in chapters.items() for room in overlay.get('map_rooms', [])}
    practices = {(item['region_id'], item['room_id']): item for item in routes.get('seal_practice_plan', [])}
    room_layouts = {(item['region_id'], item['room_id']): item
                    for item in routes.get('workshop_layouts', [])}
    bases = {r: json.loads((DATA / f'{r}.json').read_text()) for r in REGIONS}
    for overlay in chapters.values():
        for key in ['portals', 'platforms', 'locked_gates', 'collectibles', 'map_rooms', 'grapple_anchors', 'save_points', 'map_room_overrides']:
            overlay[key] = [v for v in overlay.get(key, []) if not v.get('id', '').startswith(PREFIX)
                            and v.get('generated_by') != 'world_upgrade'
                            and '可见旧检修入口：「' not in v.get('guide', '')]
        overlay['inventory_catalog'] = {k: v for k, v in overlay.get('inventory_catalog', {}).items() if not k.startswith(PREFIX)}
        overlay.pop('world_overrides', None)

    def portal(r, id_, room, point, target_r, peer, target_point, label, **options):
        result = dict(id=id_, kind='world_portal', position=point, interaction_size=[90, 110],
                      target_config_id=target_r, target_portal_id=peer, target_spawn=target_point,
                      label=label, requires_demo_complete=False, room_id=room, **options)
        chapters[r]['portals'].append(result)
        return result

    def paired(a, b, name, **a_options):
        r1, room1, p1 = a
        r2, room2, p2 = b
        id1, id2 = f'{PREFIX}{name}_a', f'{PREFIX}{name}_b'
        portal(r1, id1, room1, p1, r2, id2, p2, a_options.pop('label', '旧支线 → ' + bases[r2]['name']), **a_options)
        portal(r2, id2, room2, p2, r1, id1, p1, '旧支线 → ' + bases[r1]['name'])
        return id1, id2

    # Late-world fork can be taken before completing either late-area boss.
    # The Crown merge has the same ability gate from both approaches.
    paired((REGIONS[2], 'candle_mezzanine', [2340, 2118]),
           (REGIONS[4], 'ravine_gate', [710, 2672]), 'archive_obsidian_branch',
           required_ability='double_thread_jump', required_ability_name='双线跃',
           label='旧军用运书线 → 黑曜巡礼路', hint='双线跃接通高架线后，可先走黑曜巡礼路，或继续探索温室。')
    paired((REGIONS[3], 'root_vault', [2400, 1942]),
           (REGIONS[5], 'echo_string', [4615, 1540]), 'greenhouse_crown_branch',
           required_ability='lantern_phase', required_ability_name='灯影相位',
           label='根须影管 → 无声王冠', hint='温室根须影管需要灯影相位；黑曜巡礼路与温室可按不同顺序探索。')
    paired((REGIONS[4], 'pilgrim_camp', [220, 1870]),
           (REGIONS[1], 'wish_board_landing', [3090, 1700]), 'obsidian_rain_return',
           unlock_shortcut_id='obsidian_rain_service', label='解锁旧补给索道 → 铸雨渠')
    rain_peer = next(p for p in chapters[REGIONS[1]]['portals'] if p['id'] == PREFIX + 'obsidian_rain_return_b')
    rain_peer.update(requires_shortcut='obsidian_rain_service', unlock_shortcut_id='obsidian_rain_service',
                     label='旧补给索道 → 黑曜巡礼路', hint='补给索道的门闩在黑曜营地，需从远侧先开启。')
    # Fix the old near-end unlock: possession alone must not unlock a far-side latch.
    next(p for p in chapters[REGIONS[0]]['portals'] if p['id'] == 'moss_archive_return')['requires_shortcut'] = 'archive_return'
    for r in [REGIONS[4], REGIONS[5]]:
        p = next(p for p in chapters[r]['portals'] if p['id'] in ['world_5_6_out', 'world_6_5_back'])
        p.update(required_ability='lantern_phase', required_ability_name='灯影相位',
                 hint='冠脊索道穿过影闩，先在黑曜营地获得灯影相位。')

    # Obtain missing abilities on existing floors, without a gate requiring itself.
    obtains = {
        'bell_guard': (3, 'wax_seal_vault', 'vault_floor', 4390),
        'thorn_downstrike': (4, 'tree_heart', 'heart_floor', 2810),
        'lantern_phase': (5, 'pilgrim_camp', 'camp_floor', 330),
        'crown_resonance': (6, 'crown_antechamber', 'ante_floor', 3050),
    }
    for ability, (index, room, floor, x) in obtains.items():
        r = REGIONS[index - 1]
        p = next(p for p in bases[r]['platforms'] if p['id'] == floor)
        name, hint = ABILITIES[ability]
        chapters[r]['collectibles'].append(dict(id=PREFIX + 'obtain_' + ability, kind='item', item_id=ability,
            position=[x, p['rect'][1] - 40], room_id=room, platform_id=floor, label=name,
            ability_name=name, note='首次取得无需自身能力。' + hint))
        chapters[r]['inventory_catalog'][ability] = dict(name=name, category='Abilities', description=hint + '旧区有两处检修目标。')

    slots = {r: 0 for r in REGIONS}
    backtracks = []
    target_table = {k: list(v) for k, v in TARGETS.items()}
    for ability, (index, room, floor, pickup_x) in obtains.items():
        target_table[ability].append((index, room, floor, pickup_x + (90 if ability == 'bell_guard' else -90), ABILITIES[ability][0] + '练习工房'))
    for ability, targets in target_table.items():
        for target_index, (index, source_room, source_floor, source_x, title) in enumerate(targets):
            r = REGIONS[index - 1]
            overlay, base = chapters[r], bases[r]
            source_p = next(p for p in base['platforms'] if p['id'] == source_floor)
            source = [source_x, source_p['rect'][1] - 40]
            slot = slots[r]
            slots[r] += 1
            x, y = base['world']['width'] + 240, 240 + slot * 540
            room_id = f'{PREFIX}{ability}_{target_index + 1}'
            room_layout = room_layouts.get((r, room_id), {})
            name, hint = ABILITIES[ability]
            practice = target_index >= 2
            floor_break = ability == 'thorn_downstrike'
            floor_y = y + 390 if floor_break else y + 330
            approach_y = y + 190 if floor_break else floor_y
            landing = [x + 110, approach_y - 40]
            action_point = [x + (GATE_OFFSETS[ability] if floor_break else GATE_OFFSETS[ability] - 48), approach_y - 42]
            # Solid rectangular shells are independent of cave terrain, and never
            # have terrain_id (Main would otherwise omit their physical collider).
            platforms = [
                ('roof', [x, y, 664, 28], 'ceiling'),
                ('foundation', [x, floor_y, 664, 100], 'floor'),
                ('backwall', [x + 636, y, 28, floor_y - y + 100], 'wall'),
            ]
            if floor_break:
                platforms += [
                    ('approach', [x, approach_y, 346, 26], 'floor'),
                    ('well_wall', [x + 318, approach_y, 28, floor_y - approach_y + 10], 'wall'),
                ]
            for step in room_layout.get('platforms', []):
                offset = step['offset']
                size = step['size']
                platforms.append((step['id_suffix'], [x + offset[0], y + offset[1], size[0], size[1]],
                                  step.get('collision_role', 'floor')))
            for suffix, rect, role in platforms:
                overlay['platforms'].append(dict(id=room_id + '_' + suffix, rect=rect, collision_role=role,
                    color='385357' if ability in ['bell_guard', 'crown_resonance'] else '4c4b3e',
                    material='bronze_bridge', route_role='branch'))
            gate_id = room_id + '_action_gate'
            gate = ([x + GATE_OFFSETS[ability], approach_y - 12, x + 642 - (x + GATE_OFFSETS[ability]), 30]
                    if floor_break else [x + GATE_OFFSETS[ability], y + 20, 36, floor_y - y + 90])
            overlay['locked_gates'].append(dict(id=gate_id, rect=gate, color='b58a48', material='bronze_bridge',
                required_ability=ability, required_ability_name=name, requires_action=ability,
                permanent_action_unlock_id=gate_id, action_range=175 if floor_break else 155,
                from_room=room_id, to_room=room_id, map_marker='ability_gate',
                gate_kind='fragile_terrain' if floor_break else ('phase_gate' if ability == 'lantern_phase' else 'action_gate'),
                action_hint=hint))
            reward_offset = room_layout.get('reward_offset', [520, floor_y - y - 40])
            overlay['map_rooms'].append(dict(id=room_id, name=title, range=[x, x + 664],
                depth=slot, kind='branch', archetype='ability_backtrack',
                layout_rect=[x, y - 20, 664, floor_y - y + 140],
                play_rect=[x, y - 20, 664, floor_y - y + 140],
                camera_bounds=[x - 18, y - 50, 700, floor_y - y + 210],
                map_rect=[1800 + (index - 1) * 280, slot * 210, 236, 168],
                visit_rects=[[x, y - 20, 664, floor_y - y + 140]],
                objective=room_layout.get('objective',
                    ('在安全工房练习刚取得的' if practice else '获得能力后回访旧区，练习') + name + '，打开封口取回物资与反证。'),
                guide=room_layout.get('guide', hint + '单纯持有能力不会开门。'),
                danger=room_layout.get('danger', '安全检修空间，无敌群压迫；封口外可随时原路退出。'),
                next='检修设施返回' + source_room, setpiece=title,
                traversal_focus=room_layout.get('traversal_focus', hint), pacing_role='optional_reward',
                entry_point=landing, action_point=action_point,
                reward_landing=[x + reward_offset[0], y + reward_offset[1]],
                movement_combo=room_layout.get('movement_combo', MOVEMENT_COMBOS[ability]),
                landmark_art=dict(motif='pages' if index == 3 else 'bell', position=[x + 464, y + 80], size=[120, 160])))
            authored_room = overlay['map_rooms'][-1]
            if room_layout.get('layout_group'):
                authored_room['layout_group'] = room_layout['layout_group']
                authored_room['route_archetype'] = room_layout['variant']
                authored_room['route_steps'] = [dict(action=step['action'], position=[x + step['offset'][0], y + step['offset'][1]])
                                                for step in room_layout['route_steps']]
            previous_room = previous_rooms.get((r, room_id), {})
            for field in ['guide', 'objective']:
                if previous_room.get(field, '').startswith(authored_room[field]):
                    authored_room[field] = previous_room[field]
            # Combat practice is a separate equipment system layered onto these
            # exploration workshops. Rebuild its metadata from the retained plan
            # so regeneration cannot silently erase the six training stations.
            combat_practice = practices.get((r, room_id), previous_room.get('combat_practice'))
            if combat_practice:
                authored_room['combat_practice'] = deepcopy(combat_practice)
                label = combat_practice['label']
                if label not in authored_room['guide']:
                    authored_room['guide'] += ' ' + label
                objective = '门外练针架提供特殊技能练习，不消耗永久探索能力。'
                if objective not in authored_room['objective']:
                    authored_room['objective'] += ' ' + objective
            entrance, exit_id = paired((r, source_room, source), (r, room_id, landing), room_id.removeprefix(PREFIX) + '_access',
                label='检修支线 → ' + title)
            peer = next(p for p in overlay['portals'] if p['id'] == exit_id)
            peer['label'] = '检修设施 → 返回原通路'
            reward_offset = room_layout.get('reward_offset', [520, floor_y - y - 40])
            reward_y = y + reward_offset[1]
            reward_platform = room_layout.get('reward_platform', room_id + '_foundation')
            evidence_id = room_id + '_evidence'
            evidence_item = room_id + '_record'
            overlay['collectibles'].extend([
                dict(id=evidence_id, kind='item', item_id=evidence_item, position=[x + 494, reward_y],
                     room_id=room_id, platform_id=reward_platform, label='旧检修操作手册' if practice else EVIDENCE[ability][target_index],
                     note='能力回访反证；可选，不代替六区主线证词。'),
                dict(id=room_id + '_resin', kind='currency', item_id='currency', amount=45 + index * 5,
                     position=[x + 564, reward_y], room_id=room_id, platform_id=reward_platform, label='检修物资 · 松脂碎片'),
            ])
            overlay['inventory_catalog'][evidence_item] = dict(name=name + '检修手册' if practice else EVIDENCE[ability][target_index], category='Relics',
                description=title + '保存的工作记录：设施曾为居民维护，后来改为输送契约、军令和被抹去的声音。')
            if ability == 'echo_hook':
                overlay['grapple_anchors'].append(dict(id=room_id + '_ring', position=[x + 250, y + 150],
                    room_id=room_id, label='检修闩牵引环', required_ability='echo_hook', test_from=[x + 210, floor_y - 40]))
            for anchor in room_layout.get('extra_anchors', []):
                overlay['grapple_anchors'].append(dict(id=room_id + '_' + anchor['id_suffix'],
                    position=[x + anchor['offset'][0], y + anchor['offset'][1]], room_id=room_id,
                    label='高位检修吊环', required_ability='echo_hook',
                    test_from=[x + anchor['test_from_offset'][0], y + anchor['test_from_offset'][1]]))
            if floor_break:
                # After dropping through the breakable seal, a far-side lift opens
                # the return. Its upper endpoint cannot bypass the unopened floor.
                lift = room_id + '_return'
                top, bottom = paired((r, room_id, [x + 230, approach_y - 40]),
                    (r, room_id, [x + 420, floor_y - 40]), room_id.removeprefix(PREFIX) + '_well_lift',
                    label='深井返程升梯', requires_shortcut=lift, unlock_shortcut_id=lift)
                next(p for p in overlay['portals'] if p['id'] == bottom).update(unlock_shortcut_id=lift, label='拉开深井返程升梯')
            backtracks.append(dict(ability_id=ability, region_id=r, source_room_id=source_room,
                room_id=room_id, entry_portal_id=entrance, gate_id=gate_id,
                reward_ids=[evidence_id, room_id + '_resin'], source_position=source,
                reward_landing=[x + reward_offset[0], reward_y],
                approach_position=([x + 258, approach_y - 40] if floor_break else action_point), action_position=action_point,
                clue=hint, required_action=ability,
                role='practice' if practice else 'backtrack'))
            existing = next(v for v in base['map_rooms'] if v['id'] == source_room)
            override = next((v for v in overlay['map_room_overrides'] if v['id'] == source_room), None)
            if override is None:
                override = dict(id=source_room, guide=existing.get('guide', ''), objective=existing.get('objective', ''), generated_by='world_upgrade')
                overlay['map_room_overrides'].append(override)
            override['guide'] += ' 可见旧检修入口：「' + title + '」。' + hint
            override['objective'] += ' 可选：' + title + '。'

    for r, count in slots.items():
        if count:
            chapters[r]['world_overrides'] = dict(width=bases[r]['world']['width'] + 1120,
                height=max(bases[r]['world']['height'], 240 + (count - 1) * 540 + 570))
    routes.update(version=2,
        design_note='六区互联：书库分赴温室/黑曜，根须影管与冠脊索道在王冠汇合。三条旧补给/运书线由远侧开启；八能力各有两间安全、动作驱动、有物资和反证奖励的旧区检修工房。',
        ability_backtracks=backtracks,
        acquisition_plan={k: dict(region_id=REGIONS[v[0] - 1], room_id=v[1], collectible_id=PREFIX + 'obtain_' + k) for k, v in obtains.items()})
    PATH.write_text(json.dumps(routes, ensure_ascii=False, indent=2) + '\n')
    print(f'World upgrade authored: 3 late cross-region pairs, {len(backtracks)} action workshops (16 backtracks + 4 practices), {len(obtains)} ability acquisitions.')


if __name__ == '__main__':
    build()
