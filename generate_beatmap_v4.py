#!/usr/bin/env python3
"""
Générateur de Beatmap v4.1 - NeonPulse
Analyse audio avancée (librosa HPSS, onset_strength, beat_track, RMS + spectral contrast)
et placement spatial avec flow rythmique style osu!.
"""

import json
import sys
import os
import random
import math

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

try:
    import librosa
    import numpy as np
    HAS_LIBROSA = True
except ImportError:
    HAS_LIBROSA = False
    print("⚠️ librosa non installé - génération basique")

SCREEN_WIDTH = 1152
SCREEN_HEIGHT = 648
MARGIN = 130
SLIDER_MARGIN = 150


class BeatmapGeneratorV4:
    def __init__(self, difficulty="normal", seed=None):
        self.difficulty = difficulty.lower()
        if seed is not None:
            random.seed(seed)
        self.notes = []
        self.kiai_sections = []
        self.params = self.get_difficulty_params()
        self.last_angle = random.uniform(0, 2 * math.pi)

    def get_difficulty_params(self):
        params = {
            "easy": {
                "approach_time": 2.2,
                "min_time_gap": 1.35,
                "onset_percentile": 78,
                "use_percussive_onsets": False,
                "slider_chance": 0.08,
                "double_tap_chance": 0.0,
                "pattern_chance": 0.0,
                "pattern_step_min": 0.55,
                "flow_speed": 140.0,
                "max_jump": 170.0,
                "slider_beats": [1.0, 1.5],
            },
            "normal": {
                "approach_time": 1.8,
                "min_time_gap": 0.85,
                "onset_percentile": 62,
                "use_percussive_onsets": True,
                "slider_chance": 0.14,
                "double_tap_chance": 0.02,
                "pattern_chance": 0.03,
                "pattern_step_min": 0.42,
                "flow_speed": 190.0,
                "max_jump": 220.0,
                "slider_beats": [1.0, 1.5, 2.0],
            },
            "hard": {
                "approach_time": 1.45,
                "min_time_gap": 0.50,
                "onset_percentile": 45,
                "use_percussive_onsets": True,
                "slider_chance": 0.18,
                "double_tap_chance": 0.05,
                "pattern_chance": 0.07,
                "pattern_step_min": 0.30,
                "flow_speed": 210.0,
                "max_jump": 220.0,
                "slider_beats": [0.5, 1.0, 1.5],
            },
            "expert": {
                "approach_time": 1.20,
                "min_time_gap": 0.35,
                "onset_percentile": 30,
                "use_percussive_onsets": True,
                "slider_chance": 0.18,
                "double_tap_chance": 0.06,
                "pattern_chance": 0.12,
                "pattern_step_min": 0.24,
                "flow_speed": 235.0,
                "max_jump": 230.0,
                "slider_beats": [0.5, 1.0],
            },
        }
        return params.get(self.difficulty, params["normal"])

    def _clamp_pos(self, x, y, margin=MARGIN):
        x = max(margin, min(SCREEN_WIDTH - margin, x))
        y = max(margin, min(SCREEN_HEIGHT - margin, y))
        return (int(round(x)), int(round(y)))

    def next_flow_position(self, last_pos, dt, energy=0.5, recent_positions=None):
        """Calcule la prochaine position avec un flow naturel proportionnel au temps dt."""
        if last_pos is None:
            return (SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2)

        # Distance cible proportionnelle à dt et à l'énergie
        target_dist = clamp(dt * self.params["flow_speed"] * (0.75 + 0.5 * energy), 65.0, self.params["max_jump"])

        # Rotation douce de l'angle pour garder un flow continu (plus serré sur les notes rapides)
        max_turn = 0.65 if dt < 0.30 else 1.45
        best_pos = None
        best_score = -1e9

        for attempt in range(12):
            angle_delta = random.uniform(-max_turn, max_turn)
            if attempt > 6:
                angle_delta = random.uniform(-math.pi, math.pi)
            angle = self.last_angle + angle_delta

            nx = last_pos[0] + math.cos(angle) * target_dist
            ny = last_pos[1] + math.sin(angle) * target_dist

            # Rebond doux si hors limites
            if nx < MARGIN or nx > SCREEN_WIDTH - MARGIN:
                angle = math.pi - angle
                nx = last_pos[0] + math.cos(angle) * target_dist
            if ny < MARGIN or ny > SCREEN_HEIGHT - MARGIN:
                angle = -angle
                ny = last_pos[1] + math.sin(angle) * target_dist

            cx, cy = self._clamp_pos(nx, ny, MARGIN)

            # Évaluer la distance aux notes récentes (éviter chevauchement)
            min_recent_dist = 9999.0
            if recent_positions:
                for rp in recent_positions[-4:]:
                    d = math.hypot(cx - rp[0], cy - rp[1])
                    if d < min_recent_dist:
                        min_recent_dist = d

            score = min_recent_dist
            if MARGIN + 10 <= nx <= SCREEN_WIDTH - MARGIN - 10 and MARGIN + 10 <= ny <= SCREEN_HEIGHT - MARGIN - 10:
                score += 100.0

            if score > best_score:
                best_score = score
                best_pos = (cx, cy)
                best_angle = angle

        self.last_angle = best_angle
        return best_pos

    def generate_slider(self, start_time, start_pos, beat_duration):
        """Génère un slider musical avec courbe Bézier ou arc."""
        beats = random.choice(self.params["slider_beats"])
        duration = max(0.35, min(2.2, beat_duration * beats))
        curve_type = random.choice(["linear", "bezier", "arc_curve"])

        # Direction fluide dans la zone sûre
        angle = self.last_angle + random.uniform(-0.8, 0.8)
        length = clamp(duration * 160.0, 95.0, 230.0)
        ex = start_pos[0] + math.cos(angle) * length
        ey = start_pos[1] + math.sin(angle) * length

        if ex < SLIDER_MARGIN or ex > SCREEN_WIDTH - SLIDER_MARGIN:
            angle = math.pi - angle
            ex = start_pos[0] + math.cos(angle) * length
        if ey < SLIDER_MARGIN or ey > SCREEN_HEIGHT - SLIDER_MARGIN:
            angle = -angle
            ey = start_pos[1] + math.sin(angle) * length

        end_pos = self._clamp_pos(ex, ey, SLIDER_MARGIN)
        self.last_angle = angle

        control_points = []
        if curve_type == "bezier":
            mid_x = (start_pos[0] + end_pos[0]) * 0.5
            mid_y = (start_pos[1] + end_pos[1]) * 0.5
            perp_x = -(end_pos[1] - start_pos[1]) * 0.35
            perp_y = (end_pos[0] - start_pos[0]) * 0.35
            if random.random() < 0.5:
                perp_x, perp_y = -perp_x, -perp_y
            cp = self._clamp_pos(mid_x + perp_x, mid_y + perp_y, SLIDER_MARGIN)
            control_points = [{"x": cp[0], "y": cp[1]}]
        elif curve_type == "arc_curve":
            control_points = [{"height": random.choice([-55, 55])}]

        slider = {
            "note_type": "hold",
            "time": round(start_time, 3),
            "x": start_pos[0],
            "y": start_pos[1],
            "end_x": end_pos[0],
            "end_y": end_pos[1],
            "curve_type": curve_type,
            "control_points": control_points,
            "duration": round(duration, 3),
        }
        return slider, end_pos, start_time + duration

    def generate_pattern_stream(self, start_time, start_pos, beat_duration, upcoming_times=None, pattern_type=None):
        """Génère une séquence de notes rapides en motif géométrique, calée sur les vrais temps."""
        if pattern_type is None:
            pattern_type = random.choice(["circle", "zigzag", "diamond", "arc_flow"])

        # Subdivision rythmique exacte du BPM (jamais un délai arbitraire hors-rythme)
        if self.difficulty in ["hard", "expert"]:
            step_dt = beat_duration * 0.5 if beat_duration >= 0.48 else beat_duration
        else:
            step_dt = beat_duration if beat_duration >= 0.45 else beat_duration * 2.0

        num_notes = random.randint(3, 4) if self.difficulty in ["normal", "hard"] else random.randint(4, 5)
        pattern_times = [start_time + i * step_dt for i in range(num_notes)]
        if upcoming_times and len(upcoming_times) >= num_notes and self.difficulty in ["easy", "normal"]:
            # Utiliser directement les vrais temps détectés si disponibles
            pattern_times = upcoming_times[:num_notes]

        notes = []
        last_pos = start_pos

        if pattern_type == "circle":
            radius = random.randint(65, 95)
            cx, cy = self._clamp_pos(start_pos[0], start_pos[1], MARGIN + radius)
            for i, pt in enumerate(pattern_times):
                angle = (2 * math.pi * i) / len(pattern_times)
                px, py = self._clamp_pos(cx + math.cos(angle) * radius, cy + math.sin(angle) * radius)
                notes.append({"time": round(pt, 3), "x": px, "y": py, "pattern": "circle"})
                last_pos = (px, py)
        elif pattern_type == "diamond":
            offsets = [(0, -80), (80, 0), (0, 80), (-80, 0)]
            cx, cy = self._clamp_pos(start_pos[0], start_pos[1], MARGIN + 90)
            for i, pt in enumerate(pattern_times[:4]):
                dx, dy = offsets[i % 4]
                px, py = self._clamp_pos(cx + dx, cy + dy)
                notes.append({"time": round(pt, 3), "x": px, "y": py, "pattern": "diamond"})
                last_pos = (px, py)
        else:
            base_angle = self.last_angle
            for i, pt in enumerate(pattern_times):
                offset_angle = base_angle + (0.55 if i % 2 == 0 else -0.55)
                nx = last_pos[0] + math.cos(offset_angle) * 75
                ny = last_pos[1] + math.sin(offset_angle) * 75
                px, py = self._clamp_pos(nx, ny)
                notes.append({"time": round(pt, 3), "x": px, "y": py, "pattern": pattern_type})
                last_pos = (px, py)

        end_time = notes[-1]["time"] if notes else start_time
        return notes, last_pos, end_time

    def detect_kiai_sections(self, y, sr, duration):
        """Détecte les sections intenses (refrains/drops) via RMS + contraste spectral."""
        try:
            rms = librosa.feature.rms(y=y)[0]
            times = librosa.times_like(rms, sr=sr)
            centroid = librosa.feature.spectral_centroid(y=y, sr=sr)[0]

            rms_norm = (rms - rms.min()) / (rms.max() - rms.min() + 1e-6)
            cent_norm = (centroid - centroid.min()) / (centroid.max() - centroid.min() + 1e-6)
            n = min(len(rms_norm), len(cent_norm))
            energy = rms_norm[:n] * 0.7 + cent_norm[:n] * 0.3

            threshold = np.percentile(energy, 62)
            sections = []
            in_kiai = False
            start_t = 0.0

            for t, val in zip(times[:n], energy):
                if val > threshold and not in_kiai:
                    in_kiai = True
                    start_t = float(t)
                elif val < threshold * 0.72 and in_kiai:
                    in_kiai = False
                    if t - start_t >= 2.5:
                        sections.append({"start": round(start_t, 2), "end": round(float(t), 2)})

            if in_kiai and duration - start_t >= 2.5:
                sections.append({"start": round(start_t, 2), "end": round(duration, 2)})

            merged = []
            for sec in sections:
                if merged and sec["start"] - merged[-1]["end"] < 3.0:
                    merged[-1]["end"] = sec["end"]
                else:
                    merged.append(sec)

            if not merged and duration > 15.0:
                merged = [
                    {"start": round(duration * 0.25, 2), "end": round(duration * 0.38, 2)},
                    {"start": round(duration * 0.60, 2), "end": round(duration * 0.75, 2)},
                ]
            return merged[:5]
        except Exception as e:
            print(f"⚠️ Erreur détection kiai: {e}")
            return []

    def generate_from_audio(self, audio_path):
        if not HAS_LIBROSA:
            return self.generate_basic(120.0, 60.0)

        try:
            print(f"📊 Analyse audio avancée ({self.difficulty}): {audio_path}")
            y, sr = librosa.load(audio_path, sr=22050)
            duration = float(librosa.get_duration(y=y, sr=sr))

            # Séparation harmonique / percussive
            y_harm, y_perc = librosa.effects.hpss(y)

            # Tempo & beats
            tempo, beat_frames = librosa.beat.beat_track(y=y_perc, sr=sr)
            if hasattr(tempo, "__len__"):
                tempo = float(tempo[0])
            tempo = max(60.0, min(220.0, float(tempo)))
            beat_times = librosa.frames_to_time(beat_frames, sr=sr)
            beat_duration = 60.0 / tempo

            # Enveloppe d'énergie RMS & force d'onset
            rms = librosa.feature.rms(y=y)[0]
            rms_times = librosa.times_like(rms, sr=sr)
            rms_norm = (rms - rms.min()) / (rms.max() - rms.min() + 1e-6)

            onset_env = librosa.onset.onset_strength(y=y_perc if self.params["use_percussive_onsets"] else y, sr=sr)
            onset_frames = librosa.onset.onset_detect(
                onset_envelope=onset_env,
                sr=sr,
                wait=max(1, int(self.params["min_time_gap"] * sr / 512)),
                backtrack=False
            )
            onset_times = librosa.frames_to_time(onset_frames, sr=sr)
            onset_strengths = onset_env[onset_frames] if len(onset_frames) > 0 else np.array([])

            # Construire une grille rythmique 100% calée sur les vrais beats (multiples binaires 1, 2, 4 ou 0.5)
            beat_list = [float(bt) for bt in beat_times if 0.5 <= float(bt) <= duration - 1.0]
            if not beat_list:
                return self.generate_basic(tempo, duration)

            # Choisir le pas en nombre de beats selon le tempo réel et la difficulté
            if self.difficulty == "easy":
                # Viser ~1.0s à 1.6s entre notes, toujours sur un multiple binaire de beats (2 ou 4)
                beat_step = 4 if beat_duration < 0.42 else (2 if beat_duration < 0.85 else 1)
                grid_times = beat_list[::beat_step]
            elif self.difficulty == "normal":
                # Toujours sur les temps forts (1 beat si tempo lent, 2 beats si tempo rapide)
                beat_step = 2 if beat_duration < 0.52 else 1
                grid_times = beat_list[::beat_step]
            elif self.difficulty == "hard":
                # Tous les beats + contre-temps (1/2 beat) sur les onsets forts
                grid_times = list(beat_list)
                if len(onset_strengths) > 0:
                    strong_thresh = np.percentile(onset_strengths, 70)
                    for i in range(len(beat_list) - 1):
                        half_t = (beat_list[i] + beat_list[i + 1]) * 0.5
                        if (beat_list[i + 1] - beat_list[i]) >= 0.48:
                            # Vérifier s'il y a un onset fort près du contre-temps
                            if any(abs(float(ot) - half_t) < 0.08 and float(os_) >= strong_thresh for ot, os_ in zip(onset_times, onset_strengths)):
                                grid_times.append(half_t)
                grid_times.sort()
            else:
                # Expert: tous les beats + contre-temps sur les onsets modérés/forts
                grid_times = list(beat_list)
                if len(onset_strengths) > 0:
                    med_thresh = np.percentile(onset_strengths, 45)
                    for i in range(len(beat_list) - 1):
                        half_t = (beat_list[i] + beat_list[i + 1]) * 0.5
                        if (beat_list[i + 1] - beat_list[i]) >= 0.36:
                            if any(abs(float(ot) - half_t) < 0.09 and float(os_) >= med_thresh for ot, os_ in zip(onset_times, onset_strengths)):
                                grid_times.append(half_t)
                grid_times.sort()

            filtered_times = []
            filtered_energies = []
            for t in grid_times:
                idx = int(np.searchsorted(rms_times, t))
                idx = min(idx, len(rms_norm) - 1)
                filtered_times.append(t)
                filtered_energies.append(float(rms_norm[idx]))

            self.kiai_sections = self.detect_kiai_sections(y, sr, duration)
            print(f"🎵 Tempo: {tempo:.1f} BPM | Durée: {duration:.1f}s | Events: {len(filtered_times)} | Kiai: {len(self.kiai_sections)}")

            self.build_note_sequence(filtered_times, filtered_energies, beat_duration)
            return self.build_beatmap(tempo, duration)

        except Exception as e:
            print(f"❌ Erreur analyse audio: {e}")
            return self.generate_basic(120.0, 60.0)

    def build_note_sequence(self, times, energies, beat_duration):
        last_pos = (SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2)
        recent_positions = [last_pos]
        i = 0

        while i < len(times):
            t = times[i]
            energy = energies[i] if i < len(energies) else 0.5
            prev_t = times[i - 1] if i > 0 else t - beat_duration
            dt = max(0.12, t - prev_t)
            in_kiai = any(k["start"] <= t <= k["end"] for k in self.kiai_sections)

            rand = random.random()

            # Pattern stream pendant les moments énergiques / kiai
            if self.params["pattern_chance"] > 0 and (rand < self.params["pattern_chance"] or (in_kiai and energy > 0.65 and rand < self.params["pattern_chance"] * 1.6)):
                pattern_notes, last_pos, end_time = self.generate_pattern_stream(t, last_pos, beat_duration, times[i:i + 5])
                for pn in pattern_notes:
                    if in_kiai:
                        pn["kiai"] = True
                    recent_positions.append((pn["x"], pn["y"]))
                self.notes.extend(pattern_notes)
                while i < len(times) and times[i] <= end_time + beat_duration * 0.25:
                    i += 1
                continue

            # Slider (hold)
            if rand < self.params["slider_chance"]:
                slider, last_pos, end_time = self.generate_slider(t, last_pos, beat_duration)
                if in_kiai:
                    slider["kiai"] = True
                self.notes.append(slider)
                recent_positions.append(last_pos)
                while i < len(times) and times[i] <= end_time + beat_duration * 0.25:
                    i += 1
                continue

            # Note simple ou double_tap
            pos = self.next_flow_position(last_pos, dt, energy, recent_positions)
            note = {
                "time": round(t, 3),
                "x": pos[0],
                "y": pos[1],
            }
            if random.random() < self.params["double_tap_chance"] and dt >= 0.45:
                note["note_type"] = "double_tap"
            if in_kiai:
                note["kiai"] = True

            self.notes.append(note)
            last_pos = pos
            recent_positions.append(pos)
            i += 1

    def generate_basic(self, bpm, duration):
        beat_duration = 60.0 / bpm
        times = [i * beat_duration for i in range(1, int(duration / beat_duration))]
        energies = [0.5] * len(times)
        self.build_note_sequence(times, energies, beat_duration)
        return self.build_beatmap(bpm, duration)

    def build_beatmap(self, bpm, duration):
        self.notes.sort(key=lambda n: n.get("time", 0))
        beatmap = {
            "version": "4.1",
            "title": "Generated Beatmap",
            "artist": "NeonPulse",
            "difficulty": self.difficulty,
            "bpm": round(bpm, 1),
            "duration": round(duration, 2),
            "approach_time": self.params["approach_time"],
            "total_notes": len(self.notes),
            "kiai_sections": self.kiai_sections,
            "notes": self.notes,
        }
        num_sliders = sum(1 for n in self.notes if n.get("note_type") == "hold")
        num_double = sum(1 for n in self.notes if n.get("note_type") == "double_tap")
        print(f"✅ [{self.difficulty}] {len(self.notes)} notes (sliders: {num_sliders}, double_tap: {num_double})")
        return beatmap


def clamp(val, lo, hi):
    return max(lo, min(hi, val))


def main():
    if len(sys.argv) < 3:
        print("Usage: python generate_beatmap_v4.py <audio_file> <output_json_or_dir> [difficulty|all]")
        sys.exit(1)

    audio_path = sys.argv[1]
    output_arg = sys.argv[2]
    difficulty = sys.argv[3] if len(sys.argv) > 3 else "normal"

    if not os.path.exists(audio_path):
        print(f"❌ Fichier audio non trouvé: {audio_path}")
        sys.exit(1)

    if difficulty == "all":
        out_dir = output_arg if os.path.isdir(output_arg) else os.path.dirname(output_arg) or "."
        for diff in ["easy", "normal", "hard", "expert"]:
            gen = BeatmapGeneratorV4(diff, seed=42)
            bm = gen.generate_from_audio(audio_path)
            out_file = os.path.join(out_dir, f"beatmap_{diff}.json")
            with open(out_file, "w", encoding="utf-8") as f:
                json.dump(bm, f, indent=2, ensure_ascii=False)
            print(f"💾 Sauvegardée: {out_file}")
    else:
        gen = BeatmapGeneratorV4(difficulty, seed=42)
        bm = gen.generate_from_audio(audio_path)
        with open(output_arg, "w", encoding="utf-8") as f:
            json.dump(bm, f, indent=2, ensure_ascii=False)
        print(f"💾 Beatmap sauvegardée: {output_arg}")


if __name__ == "__main__":
    main()
