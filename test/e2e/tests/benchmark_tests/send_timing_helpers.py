"""Shared helpers for message send timing benchmark tests."""

import shutil
import time

from allure_commons._allure import step

import configs
from driver.aut import AUT
from scripts.utils.benchmark_report import (
    BenchmarkScenarioSamples,
    attach_scenario_reports,
    monitored_timed_call,
)

PLAIN_TEXT_LENGTH = 1000
PLAIN_TEXT_MARKER = 'e2e-bench-plain-'
ALBUM_IMAGE_COUNT = 5
BATCH_MESSAGE_COUNT = 10
BATCH_DELAY_SEC = 0.5
GIF_URL = 'https://media1.giphy.com/media/lcG3qwtTKSNI2i5vst/giphy.gif'


def _plain_text_payload(length: int = PLAIN_TEXT_LENGTH) -> str:
    # TextEdit.Wrap only breaks on word boundaries; a 1000-char token clips the input.
    filler = 'word '
    needed = length - len(PLAIN_TEXT_MARKER)
    return PLAIN_TEXT_MARKER + (filler * ((needed // len(filler)) + 1))[:needed]


def _album_image_paths(tmp_path, count: int = ALBUM_IMAGE_COUNT):
    source = configs.testpath.TEST_IMAGES / 'comm_logo.jpeg'
    return [shutil.copy(source, tmp_path / f'album_{index}.jpeg') for index in range(count)]


def _until_label(include_delivered: bool) -> str:
    return 'Sent and Delivered' if include_delivered else 'Sent'


def _record_send(
        aut: AUT,
        sent_samples: BenchmarkScenarioSamples,
        delivered_samples: BenchmarkScenarioSamples,
        send_action,
        chat,
        message_text=None,
        after_message_id=None,
        include_delivered: bool = True,
        after_sent=None,
) -> str:
    started_at = time.perf_counter()
    send_action()

    message, _, sent_stats = monitored_timed_call(
        aut,
        lambda: chat.wait_until_outgoing_sent(message_text, after_message_id=after_message_id),
    )
    sent_samples.record(time.perf_counter() - started_at, sent_stats)
    if not include_delivered:
        return message.message_id

    if after_sent is not None:
        after_sent(message_text)

    delivered_message, _, delivered_stats = monitored_timed_call(
        aut,
        lambda: chat.wait_until_outgoing_delivered(message_text, after_message_id=after_message_id),
    )
    delivered_samples.record(time.perf_counter() - started_at, delivered_stats)
    return delivered_message.message_id


def _attach_reports(
        tmp_path,
        subject: str,
        slug: str,
        sent_samples: BenchmarkScenarioSamples,
        delivered_samples: BenchmarkScenarioSamples,
        include_delivered: bool = True,
) -> None:
    attach_scenario_reports(
        tmp_path, subject=f'{subject} Sent', slug=f'{slug}_sent', samples=sent_samples,
    )
    if include_delivered:
        attach_scenario_reports(
            tmp_path,
            subject=f'{subject} Delivered',
            slug=f'{slug}_delivered',
            samples=delivered_samples,
        )


def _measure_send(
        tmp_path,
        aut: AUT,
        chat,
        subject: str,
        slug: str,
        send_action,
        include_delivered: bool = True,
        after_sent=None,
        **wait_kwargs,
) -> str:
    sent_samples = BenchmarkScenarioSamples()
    delivered_samples = BenchmarkScenarioSamples()
    message_id = _record_send(
        aut,
        sent_samples,
        delivered_samples,
        send_action,
        chat,
        include_delivered=include_delivered,
        after_sent=after_sent,
        **wait_kwargs,
    )
    _attach_reports(tmp_path, subject, slug, sent_samples, delivered_samples, include_delivered)
    return message_id


def run_send_timing_scenarios(
        tmp_path,
        aut: AUT,
        chat,
        composer,
        subject_prefix: str,
        slug_prefix: str,
        include_delivered: bool = True,
        after_sent=None,
) -> None:
    until = _until_label(include_delivered)
    album_paths = _album_image_paths(tmp_path)

    with step(f'Send 1000-character text and measure time until {until}'):
        composer.type_message(_plain_text_payload())
        plain_text_message_id = _measure_send(
            tmp_path,
            aut,
            chat,
            f'{subject_prefix} 1000-char text',
            f'{slug_prefix}_plain_text',
            composer.confirm_sending_message,
            message_text=PLAIN_TEXT_MARKER,
            include_delivered=include_delivered,
            after_sent=after_sent,
        )

    with step(f'Send 5-image album and measure time until {until}'):
        composer.choose_images(album_paths)
        _measure_send(
            tmp_path,
            aut,
            chat,
            f'{subject_prefix} image album',
            f'{slug_prefix}_album',
            composer.send_message,
            after_message_id=plain_text_message_id,
            include_delivered=include_delivered,
            after_sent=after_sent,
        )

    with step(f'Send GIF and measure time until {until}'):
        _measure_send(
            tmp_path,
            aut,
            chat,
            f'{subject_prefix} GIF',
            f'{slug_prefix}_gif',
            lambda: composer.send_gif_to_chat(GIF_URL),
            message_text=GIF_URL,
            include_delivered=include_delivered,
            after_sent=after_sent,
        )

    with step(
            f'Send {BATCH_MESSAGE_COUNT} texts with {BATCH_DELAY_SEC}s delay '
            f'and measure each until {until}'
    ):
        sent_samples = BenchmarkScenarioSamples()
        delivered_samples = BenchmarkScenarioSamples()
        for index in range(BATCH_MESSAGE_COUNT):
            payload = f'e2e-bench-burst-{index:02d}'
            composer.type_message(payload)
            _record_send(
                aut,
                sent_samples,
                delivered_samples,
                composer.confirm_sending_message,
                chat,
                message_text=payload,
                include_delivered=include_delivered,
                after_sent=after_sent,
            )
            if index < BATCH_MESSAGE_COUNT - 1:
                time.sleep(BATCH_DELAY_SEC)
        _attach_reports(
            tmp_path,
            f'{subject_prefix} 10-message burst',
            f'{slug_prefix}_burst',
            sent_samples,
            delivered_samples,
            include_delivered,
        )
