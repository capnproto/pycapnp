"""logging"""

# Copyright (c) PyZMQ Developers.
# Distributed under the terms of the Modified BSD License.

from __future__ import division

import os
import sys
import logging

#
# Logging (adapted from h5py: http://h5py.googlecode.com)
#


logger = logging.getLogger()
if os.environ.get('DEBUG'):
    logger.setLevel(logging.DEBUG)
else:
    logger.setLevel(logging.INFO)
logger.addHandler(logging.StreamHandler(sys.stderr))

def debug(msg):
    """Debug"""
    logger.debug(msg)

def info(msg):
    """Info"""
    logger.info(msg)

def fatal(msg, code=1):
    """Fatal"""
    logger.error("Fatal: %s", msg)
    exit(code)

def warn(msg):
    """Warning"""
    logger.error("Warning: %s", msg)

def line(c='*', width=48):
    """Horizontal rule"""
    print(c * (width // len(c)))
