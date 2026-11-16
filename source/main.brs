' TunerBox TV - entry point
'' Deep link / ECP launch (contentId = channel number):
'   curl -d '' "http://<roku-ip>:8060/launch/dev?contentId=52&mediaType=live"
'   curl -d '' "http://<roku-ip>:8060/input?contentId=52&mediaType=live"     (while running)
' Server address:  curl -d '' "http://<roku-ip>:8060/launch/dev?host=192.168.1.50"
sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    ' the colour theme, before any screen draws (see themeChosen in utils.brs)
    screen.getGlobalNode().addFields({ theme: themeChosen() })
    scene = screen.CreateScene("MainScene")
    screen.Show()

    scene.observeField("exitApp", port)

    input = CreateObject("roInput")
    input.SetMessagePort(port)

    ' memory monitoring (certification): warn when the app nears its memory limit or the device runs low
    memMon = CreateObject("roAppMemoryMonitor")
    if memMon <> invalid then
        memMon.SetMessagePort(port)
        memMon.EnableMemoryWarningEvent(true)
        logMemory(memMon, "start")
    end if
    devInfo = CreateObject("roDeviceInfo")
    devInfo.SetMessagePort(port)
    devInfo.EnableLowGeneralMemoryEvent(true)

    handleArgs(scene, args)

    while true
        msg = Wait(0, port)
        msgType = Type(msg)
        if msgType = "roSGScreenEvent" then
            if msg.isScreenClosed() then return
        else if msgType = "roSGNodeEvent" then
            if msg.getField() = "exitApp" then return
        else if msgType = "roInputEvent" then
            handleArgs(scene, msg.getInfo())
        else if msgType = "roAppMemoryNotificationEvent" then
            logMemory(memMon, "warning")
        else if msgType = "roDeviceInfoEvent" then
            info = msg.GetInfo()
            if info <> invalid and info.generalMemoryLevel <> invalid then
                print "[memory] device memory level: "; info.generalMemoryLevel
            end if
        end if
    end while
end sub

sub logMemory(memMon as Object, why as String)
    if memMon = invalid then return
    print "[memory] "; why; ": "; memMon.GetMemoryLimitPercent(); "% of limit used, "; memMon.GetChannelAvailableMemory(); " KB available"
    print "[memory] limit: "; FormatJson(memMon.GetChannelMemoryLimit())
end sub

' launch params and roInput events carry the same fields
sub handleArgs(scene as Object, args as Dynamic)
    if args = invalid then return
    if args.host <> invalid and args.host <> "" then scene.launchHost = args.host
    if args.contentId <> invalid and args.contentId <> "" then
        mt = ""
        if args.mediaType <> invalid then mt = args.mediaType
        scene.deepLink = { contentId: args.contentId, mediaType: mt }
    end if
end sub
