"""The metronome onset and the accepted early window have different purposes."""
import unittest

import numpy as np

from tools.rhythm_tester.session import TapJudge
from tools.rhythm_tester.widgets import beat_flash


class VisualBeatTimingTests(unittest.TestCase):
    def test_early_window_does_not_make_the_metronome_flash_early(self):
        times = np.array([1.0, 1.5, 2.0])
        judge = TapJudge(times, 90)
        self.assertEqual(judge.tap(.93, "J")["judgement"], "hit")
        self.assertEqual(beat_flash(times, .93), 0)
        self.assertEqual(beat_flash(times, .999), 0)
        self.assertEqual(beat_flash(times, 1), 1)
        self.assertGreater(beat_flash(times, 1.04), 0)
        self.assertEqual(beat_flash(times, 1.09), 0)
        self.assertEqual(beat_flash(times, 1.49), 0)
        self.assertEqual(beat_flash(times, 1.5), 1)

    def test_empty_reference_and_zero_start(self):
        self.assertEqual(beat_flash(np.array([]), 1), 0)
        self.assertEqual(beat_flash(np.array([0.0]), 0), 1)


if __name__ == "__main__":
    unittest.main()
