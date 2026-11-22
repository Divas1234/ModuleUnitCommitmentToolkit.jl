import os
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "gui"))

import server  # noqa: E402


class TestRunManagerCommands(unittest.TestCase):
    def setUp(self):
        self.mgr = server.RunManager()

    def test_pcm_methods_route_to_unified_main(self):
        expected = {
            "pcm_standard": "standard",
            "pcm_clustered": "clustered_pcm",
            "pcm_adaptive": "adaptive_overlap",
            "pcm_clustered_adaptive": "clustered_adaptive_overlap",
        }
        for task, method in expected.items():
            cmd, env = self.mgr._build_cmd(task, {"pcm_profile": "smooth"})
            self.assertEqual(cmd[-2:], ["--project=.", "tools/pcm/main.jl"])
            self.assertEqual(env["PCM_METHOD"], method)
            self.assertEqual(env["PCM_LOAD_PROFILE"], "smooth")

    def test_pcm_suite_and_tests_commands(self):
        cmd, env = self.mgr._build_cmd("pcm_suite", {"pcm_profile": "baseline"})
        self.assertEqual(cmd[-1], "tools/pcm/benchmark/run_suite.jl")
        self.assertEqual(env["PCM_SUITE_PROFILES"], "baseline")

        cmd, env = self.mgr._build_cmd("tests", {})
        self.assertEqual(cmd[-1], "test/runtests.jl")
        self.assertEqual(env["MODULE_UC_TEST_ACTIVATE_LOCAL_PROJECT"], "0")

    def test_unknown_task_rejected(self):
        with self.assertRaises(ValueError):
            self.mgr._build_cmd("nonexistent_task", {})


if __name__ == "__main__":
    unittest.main()
