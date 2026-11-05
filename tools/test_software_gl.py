"""Keep TCP software-GL displays independent of shared-memory IPC."""
from contextlib import ExitStack
import ctypes
import ctypes.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import MagicMock, patch

import software_gl as display


class DisplayLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.directory = Path(self.stack.enter_context(tempfile.TemporaryDirectory()))
        self.stack.enter_context(patch.object(display.shutil, 'which', return_value='/usr/bin/Xvfb'))
        self.stack.enter_context(patch.object(display.Path, 'exists', return_value=False))
        self.stack.enter_context(patch.object(display.socket, 'socket'))
        self.stack.enter_context(patch.object(display.socket, 'create_connection'))
        self.launch = self.stack.enter_context(patch.object(display.subprocess, 'Popen'))
        self.server = MagicMock()
        self.server.poll.return_value = None
        self.server.wait.return_value = 0
        self.launch.return_value = self.server

    def test_tcp_display_does_not_advertise_shared_memory_transport(self):
        with display.software_gl(self.directory) as env:
            command = self.launch.call_args.args[0]
            self.assertEqual(command[:2], ['Xvfb', ':90'])
            self.assertIn('-extension', command)
            self.assertEqual(command[command.index('-extension') + 1], 'MIT-SHM')
            self.assertEqual(command[command.index('-listen') + 1], 'tcp')
            self.assertIn('1280x720x24', command)
            self.assertEqual(env, {'DISPLAY': '127.0.0.1:90', 'LIBGL_ALWAYS_SOFTWARE': '1'})
        self.server.terminate.assert_called_once_with()
        self.server.wait.assert_called_once_with(timeout=5)
        self.server.kill.assert_not_called()

    def test_suite_exception_still_releases_its_display(self):
        with self.assertRaisesRegex(RuntimeError, 'fixture failure'):
            with display.software_gl(self.directory):
                raise RuntimeError('fixture failure')
        self.server.terminate.assert_called_once_with()
        self.server.wait.assert_called_once_with(timeout=5)

    def test_hung_shutdown_is_killed_before_return(self):
        self.server.wait.side_effect = [subprocess.TimeoutExpired('Xvfb', 5), 0]
        with display.software_gl(self.directory):
            pass
        self.server.kill.assert_called_once_with()
        self.assertEqual(self.server.wait.call_count, 2)

    def test_dead_server_is_not_a_headless_success(self):
        self.server.poll.return_value = 1
        with self.assertRaisesRegex(RuntimeError, 'Xvfb exited during startup'):
            with display.software_gl(self.directory):
                self.fail('dead display must not yield a renderer environment')
        self.server.terminate.assert_called_once_with()

    def test_missing_xvfb_is_not_a_headless_success(self):
        with patch.object(display.shutil, 'which', return_value=None):
            with self.assertRaisesRegex(RuntimeError, 'no headless fallback'):
                with display.software_gl(self.directory):
                    self.fail('missing display must not yield a renderer environment')
        self.launch.assert_not_called()


@unittest.skipUnless(shutil.which('Xvfb') and ctypes.util.find_library('X11'),
                     'live X11 check requires Xvfb and libX11')
class LiveDisplayTests(unittest.TestCase):
    def test_live_xserver_rejects_mit_shm_extension_negotiation(self):
        x11 = ctypes.CDLL(ctypes.util.find_library('X11'))
        x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
        x11.XOpenDisplay.restype = ctypes.c_void_p
        x11.XQueryExtension.argtypes = [ctypes.c_void_p, ctypes.c_char_p,
                                       ctypes.POINTER(ctypes.c_int),
                                       ctypes.POINTER(ctypes.c_int),
                                       ctypes.POINTER(ctypes.c_int)]
        x11.XQueryExtension.restype = ctypes.c_int
        x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
        x11.XCloseDisplay.restype = ctypes.c_int
        with tempfile.TemporaryDirectory() as directory:
            with display.software_gl(Path(directory)) as env:
                connection = x11.XOpenDisplay(env['DISPLAY'].encode())
                self.assertTrue(connection, 'the actual TCP X display must accept a client')
                try:
                    opcode, event, error = ctypes.c_int(), ctypes.c_int(), ctypes.c_int()
                    present = x11.XQueryExtension(connection, b'MIT-SHM',
                                                 ctypes.byref(opcode), ctypes.byref(event),
                                                 ctypes.byref(error))
                    self.assertFalse(present, 'a remote renderer must never negotiate MIT-SHM')
                finally:
                    x11.XCloseDisplay(connection)


if __name__ == '__main__':
    unittest.main()
