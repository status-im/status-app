import time

from . import actions


def move(obj: object, x: int, y: int, dx: int, dy: int, step: int, sleep: float = 0):
    while True:
        if x > dx:
            x -= step
            if x < dx:
                x = dx
        elif x < dx:
            x += step
            if x > dx:
                x = dx
        if y > dy:
            y -= step
            if y < dy:
                y = dy
        elif y < dy:
            y += step
            if y > dy:
                y = dy
        actions.move(obj, x, y)
        time.sleep(sleep)
        if x == dx and y == dy:
            break


def press_and_move(
        obj,
        x: int,
        y: int,
        dx: int,
        dy: int,
        button: str = 'left',
        step: int = 1,
        sleep: float = 0
):
    actions.move(obj, x, y)
    actions.press(obj, x, y, button)
    move(obj, x, y, dx, dy, step, sleep)
    actions.release(button)
    time.sleep(1)

def scroll(
        obj,
        x: int,
        y: int,
        dx: int,
        dy: int,
        steps: int = 1,
        sleep: float = 0
):
    for _ in range(steps):
        actions.wheel(obj, x, y, dx, dy)
        time.sleep(sleep)
