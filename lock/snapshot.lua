-- mpv script used by wallpaper-rotate.sh: once the image has loaded, save one
-- frame at the video's own size with the user shaders applied, then quit.
-- The output path comes from --script-opts=snapshot-out=<file>.
mp.register_event("file-loaded", function()
  mp.add_timeout(0.3, function()
    mp.commandv("screenshot-to-file", mp.get_opt("snapshot-out"), "video")
    mp.command("quit")
  end)
end)
