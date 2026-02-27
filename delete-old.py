import requests
import os

headers = {
    'Authorization': f"token {os.getenv('GITHUB_TOKEN')}",
    'Accept': 'application/vnd.github.v3+json'
}

while True:
    url = f"https://api.github.com/repos/bigdaddy-1/OpenWrt/releases"
    response = requests.get(url, headers=headers)
    releases = response.json()

    url = f"https://api.github.com/repos/bigdaddy-1/OpenWrt/tags"
    response = requests.get(url, headers=headers)
    tags = response.json()

    if not releases and not tags:
        break

    for release in releases:
        release_id = release['id']
        delete_url = f"https://api.github.com/repos/bigdaddy-1/OpenWrt/releases/{release_id}"
        response = requests.delete(delete_url, headers=headers)
        if response.status_code == 204:
            print(f"Release {release_id} deleted successfully.")
        else:
            print(f"Failed to delete release {release_id}. Status code: {response.status_code}")

    for tag in tags:
        tag_name = tag['name']
        delete_url = f"https://api.github.com/repos/bigdaddy-1/OpenWrt/git/refs/tags/{tag_name}"
        response = requests.delete(delete_url, headers=headers)
        if response.status_code == 204:
            print(f"Tag {tag_name} deleted successfully.")
        else:
            print(f"Failed to delete tag {tag_name}. Status code: {response.status_code}")
