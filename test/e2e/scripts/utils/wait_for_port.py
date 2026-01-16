import time
import socket
import logging

LOG = logging.getLogger(__name__)


def wait_for_port(host: str, port: int, timeout: int = 3, retries: int = 0):
    """
    Wait for a TCP port to become available.
    
    Args:
        host: Hostname to connect to
        port: Port number to check
        timeout: Connection timeout per attempt (seconds)
        retries: Number of retry attempts (total attempts = retries + 1)
    """
    check_interval = 0.5  # Use shorter sleep intervals to avoid blocking on Windows CI
    
    for i in range(retries + 1):
        try:
            LOG.debug('Checking TCP port: %s:%d (attempt %d/%d)', host, port, i + 1, retries + 1)
            # Use connect_ex for non-blocking check, then verify with create_connection
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(timeout)
            result = sock.connect_ex((host, port))
            sock.close()
            
            if result == 0:
                # Port is open, verify with actual connection
                try:
                    with socket.create_connection((host, port), timeout=timeout):
                        LOG.info('TCP port %s:%d is available', host, port)
                        return
                except OSError as err:
                    LOG.debug('Verification connection failed: %s', err)
                    # Port might be in TIME_WAIT state, continue retrying
                    pass
        except (OSError, socket.error, socket.timeout) as err:
            LOG.debug('Connection error on attempt %d: %s', i + 1, err)
        except Exception as err:
            LOG.debug('Unexpected error checking port: %s', err)
        
        # Only sleep if not on last attempt
        if i < retries:
            time.sleep(check_interval)

    LOG.error('Timed out waiting for TCP port: %s:%d after %d attempts', host, port, retries + 1)
    raise TimeoutError(
        'Unable to establish TCP connection with %s:%d after %d attempts (timeout=%ds per attempt).' 
        % (host, port, retries + 1, timeout)
    )
