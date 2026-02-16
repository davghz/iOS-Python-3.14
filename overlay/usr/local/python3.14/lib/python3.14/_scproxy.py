"""iOS compatibility stub for Darwin _scproxy module.

The real _scproxy extension is macOS-specific. On jailbroken iOS we don't
have SystemConfiguration proxy APIs exposed the same way, but urllib/pip only
need these calls to exist.
"""


def _get_proxy_settings():
    return {}


def _get_proxies():
    return {}
