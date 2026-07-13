import unittest

import gui.server as server


class GuiSecurityTests(unittest.TestCase):
    def test_run_request_validation(self):
        task, params = server.validate_run_request(
            {"task": "ccg", "params": {"scenario_limit": 3}}
        )
        self.assertEqual(task, "ccg")
        self.assertEqual(params["scenario_limit"], 3)

        with self.assertRaises(ValueError):
            server.validate_run_request({"task": "ccg", "params": {"shell": "rm -rf"}})
        with self.assertRaises(ValueError):
            server.validate_run_request({"task": "ccg", "params": {"scenario_limit": 0}})
        with self.assertRaises(ValueError):
            server.validate_run_request({"task": "benchmark", "params": {"scenario_counts": "1;2"}})

    def test_config_update_validation(self):
        with self.assertRaises(ValueError):
            server.validate_config_updates({"unknown_key": 1})
        with self.assertRaises(ValueError):
            server.validate_config_updates({"MODEL_CONSIDER_BESS": float("inf")})

    def test_remote_binding_requires_explicit_security(self):
        original = (
            server.GUI_HOST,
            server.GUI_ALLOW_REMOTE,
            server.GUI_TOKEN,
            server.GUI_ALLOWED_ORIGINS,
        )
        try:
            server.GUI_HOST = "0.0.0.0"
            server.GUI_ALLOW_REMOTE = False
            server.GUI_TOKEN = ""
            server.GUI_ALLOWED_ORIGINS = set()
            with self.assertRaises(RuntimeError):
                server.validate_server_config()

            server.GUI_ALLOW_REMOTE = True
            server.GUI_TOKEN = "test-token"
            with self.assertRaises(RuntimeError):
                server.validate_server_config()

            server.GUI_ALLOWED_ORIGINS = {"https://dashboard.example.com"}
            server.validate_server_config()
        finally:
            (
                server.GUI_HOST,
                server.GUI_ALLOW_REMOTE,
                server.GUI_TOKEN,
                server.GUI_ALLOWED_ORIGINS,
            ) = original

    def test_loopback_detection(self):
        self.assertTrue(server.is_loopback_host("127.0.0.1"))
        self.assertTrue(server.is_loopback_host("localhost"))
        self.assertFalse(server.is_loopback_host("0.0.0.0"))


if __name__ == "__main__":
    unittest.main()
