from bs4 import BeautifulSoup


def remove_tags(html):
    # Handle None or empty input
    if html is None:
        return ''
    if not isinstance(html, str):
        return str(html) if html else ''
    # parse html content
    soup = BeautifulSoup(html, "html.parser")

    for data in soup(['style', 'script']):
        # Remove tags
        data.decompose()

    # return data by retrieving the tag content
    return ' '.join(soup.stripped_strings)
