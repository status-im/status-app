from gui.main_window import MainWindow


def test_check_market_tab(main_screen: MainWindow):
    market_tab = main_screen.left_panel.open_market_screen()

    assert str(market_tab.header.object.text) == 'Market'
    assert market_tab.tokens_list.is_visible, f'Tokens list is not displayed'
    assert market_tab.open_swap_modal(), f'Could not open swap modal from market tab'
    assert market_tab.get_tokens_list(), f'No tokens displayed in the grid'