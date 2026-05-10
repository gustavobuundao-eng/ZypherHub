
-- Zyfer Hub v1.0 - v8
-- FIX 1: Proximity Fling movido para aba Skills
-- FIX 2: Aimbot RMB one-shot lock (so gruda se tiver alguem na mira; teleporte libera)
-- FIX 3: Loader transparente com blur; hub aparece gradualmente
-- FIX 4: Modo camera bloqueia botoes do mouse no personagem
-- FIX 5: Modo camera scroll zoom in/out
-- FIX 6: Modo camera LeftCtrl = velocidade reduzida
-- FIX 7: Passo Fantasma com limite de distancia
-- FIX 8: Jogadores: acoes rapidas por player
-- FIX 9: Aba Amigos removida
-- FIX 10: Bolinha desativada por padrao ao iniciar
-- FIX 11: Pressionar Z (transformacao) nao aciona teclas do hub
-- FIX 12: Janela responsiva com escala automatica e resize seguro por viewport
-- FIX 13: Reiniciar Hub agora abre uma nova sessao para encerrar loops antigos
-- FIX 14: Auto-cleanup antes de carregar uma nova copia do hub

local function BZClearPlayerHighlights()
    pcall(function()
        local Players_=game:GetService("Players")
        for _,p in ipairs(Players_:GetPlayers()) do
            local char=p.Character
            if char then
                for _,h in ipairs(char:GetChildren()) do
                    if h:IsA("Highlight") and (h.Name=="_BZPlayerHighlight" or h.Name=="_BZWhiteOutline") then
                        h:Destroy()
                    end
                end
            end
        end
    end)
end

local BZ_QUICK_LINE_ENABLED=false
local BZ_QUICK_DEBUG=true
local BZ_QUICK_LAST=0
local function BZQDebug(msg)
    if BZ_QUICK_DEBUG then print("[Zyfer QuickMenu] "..tostring(msg)) end
end
local function BZClearQuickMenu()
    pcall(function()
        BZQDebug("limpando menu rapido")
        local st=_G.BZQuickMenuState
        if not st then return end
        if st.gui then st.gui:Destroy() end
        if st.beam then st.beam:Destroy() end
        if st.a0 then st.a0:Destroy() end
        if st.a1 then st.a1:Destroy() end
        if st.conn then st.conn:Disconnect() end
        _G.BZQuickMenuState=nil
    end)
end

local function BZClearMarkedPlayer()
    pcall(function()
        local st=_G.BZMarkedPlayerState
        if not st then return end
        BZQDebug("removendo marcacao de player")
        if st.conn then st.conn:Disconnect() end
        if st.beam then st.beam:Destroy() end
        if st.a0 then st.a0:Destroy() end
        if st.a1 then st.a1:Destroy() end
        if st.tag then st.tag:Destroy() end
        _G.BZMarkedPlayerState=nil
    end)
end

local function BZMarkQuickPlayer(target,localPlayer,notifyFn)
    if not target or not target.Parent or target==localPlayer then
        if notifyFn then notifyFn("Player invalido para marcar",Color3.fromRGB(255,75,75)) end
        return
    end
    local myChar=localPlayer and localPlayer.Character
    local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
    local char=target.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot or not root then
        if notifyFn then notifyFn("Nao foi possivel marcar o player",Color3.fromRGB(255,75,75)) end
        return
    end
    BZClearMarkedPlayer()
    local st={target=target}
    _G.BZMarkedPlayerState=st
    st.a0=Instance.new("Attachment",myRoot)
    st.a1=Instance.new("Attachment",root)
    st.beam=Instance.new("Beam")
    st.beam.Name="_BZMarkedPlayerLine"
    st.beam.Attachment0=st.a0; st.beam.Attachment1=st.a1
    st.beam.Width0=0.045; st.beam.Width1=0.045
    st.beam.Color=ColorSequence.new(Color3.fromRGB(160,90,255))
    st.beam.Transparency=NumberSequence.new(0.32)
    st.beam.FaceCamera=true
    st.beam.Parent=myRoot
    st.tag=Instance.new("Highlight")
    st.tag.Name="_BZMarkedPlayer"
    st.tag.Adornee=char
    st.tag.OutlineColor=Color3.fromRGB(255,255,255)
    st.tag.FillColor=Color3.fromRGB(130,0,255)
    st.tag.FillTransparency=1
    st.tag.OutlineTransparency=0
    st.tag.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    st.tag.Parent=char
    st.conn=game:GetService("RunService").RenderStepped:Connect(function()
        local s=_G.BZMarkedPlayerState
        if not s then return end
        local t=s.target
        local tChar=t and t.Character
        local hum=tChar and tChar:FindFirstChildOfClass("Humanoid")
        local tRoot=tChar and tChar:FindFirstChild("HumanoidRootPart")
        local lRoot=localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not t or not t.Parent or not hum or hum.Health<=0 or not tRoot or not lRoot then
            BZClearMarkedPlayer()
            return
        end
        if s.a0 and s.a0.Parent~=lRoot then s.a0.Parent=lRoot end
        if s.a1 and s.a1.Parent~=tRoot then s.a1.Parent=tRoot end
        if s.beam then s.beam.Parent=lRoot end
        if s.tag then
            if s.tag.Parent~=tChar then s.tag.Parent=tChar end
            s.tag.Adornee=tChar
        end
    end)
    BZQDebug("player marcado: "..target.Name)
    if notifyFn then notifyFn("Player marcado: "..target.Name,Color3.fromRGB(160,90,255)) end
end

local function BZFindQuickTarget(localPlayer,players,camera)
    BZQDebug("procurando player alvo")
    local myChar=localPlayer and localPlayer.Character
    local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not camera then BZQDebug("sem HumanoidRootPart local ou camera"); return nil end
    local center=Vector2.new(camera.ViewportSize.X/2,camera.ViewportSize.Y/2)
    local best,bestScore=nil,math.huge
    local near,nearDist=nil,math.huge
    for _,p in ipairs(players:GetPlayers()) do
        if p~=localPlayer and p.Character then
            local hum=p.Character:FindFirstChildOfClass("Humanoid")
            local root=p.Character:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health>0 and root then
                local dist=(root.Position-myRoot.Position).Magnitude
                local sp,on=camera:WorldToViewportPoint(root.Position+Vector3.new(0,2,0))
                if dist<nearDist and dist<=55 then near,nearDist=p,dist end
                if on and dist<=180 then
                    local screenDist=(Vector2.new(sp.X,sp.Y)-center).Magnitude
                    local dir=(root.Position-camera.CFrame.Position).Unit
                    local angle=math.deg(math.acos(math.clamp(camera.CFrame.LookVector:Dot(dir),-1,1)))
                    local score=screenDist+angle*5+dist*0.12
                    if screenDist<=220 and angle<=55 and score<bestScore then best,bestScore=p,score end
                elseif dist<=28 and dist<bestScore then
                    best,bestScore=p,dist
                end
            end
        end
    end
    if not best then best=near end
    BZQDebug(best and ("player encontrado: "..best.Name) or "nenhum player encontrado")
    return best
end

local function BZShowQuickMenu(target,localPlayer,parent,notifyFn)
    if not target or not target.Character then BZQDebug("alvo invalido ao criar menu"); return end
    local root=target.Character:FindFirstChild("HumanoidRootPart")
    if not root then BZQDebug("alvo sem HumanoidRootPart"); return end
    BZQDebug("criando/anexando menu em "..target.Name)
    local st=_G.BZQuickMenuState
    if not st then st={}; _G.BZQuickMenuState=st end
    if not st.gui then
        st.gui=Instance.new("BillboardGui")
        st.gui.Name="_BZQuickPlayerMenu"; st.gui.AlwaysOnTop=true
        st.gui.Size=UDim2.new(0,42,0,124); st.gui.StudsOffset=Vector3.new(3.4,1.7,0)
        st.gui.LightInfluence=0; st.gui.MaxDistance=260
        pcall(function() st.gui.Active=true end)
        st.gui.Parent=(localPlayer and localPlayer:FindFirstChild("PlayerGui")) or (parent and parent.Parent) or parent
        BZQDebug("BillboardGui parent: "..(st.gui.Parent and st.gui.Parent:GetFullName() or "nil"))
        local holder=Instance.new("Frame",st.gui)
        holder.BackgroundTransparency=1; holder.Size=UDim2.new(1,0,1,0)
        local ll=Instance.new("UIListLayout",holder)
        ll.Padding=UDim.new(0,7); ll.SortOrder=Enum.SortOrder.LayoutOrder
        ll.HorizontalAlignment=Enum.HorizontalAlignment.Center
        for i=1,3 do
            local idx=i
            local b=Instance.new("TextButton",holder)
            b.Name="Action"..i; b.Size=UDim2.new(0,34,0,34); b.BackgroundColor3=Color3.fromRGB(22,22,34)
            b.BackgroundTransparency=0.08; b.BorderSizePixel=0
            b.Text=({[1]="M",[2]="+",[3]="TP"})[i] or tostring(i)
            b.TextColor3=Color3.new(1,1,1); b.TextSize=i==3 and 10 or 13; b.Font=Enum.Font.GothamBold
            b.LayoutOrder=i; b.AutoButtonColor=false
            local c=Instance.new("UICorner",b); c.CornerRadius=UDim.new(0,99)
            local s=Instance.new("UIStroke",b); s.Color=Color3.fromRGB(255,255,255); s.Thickness=1; s.Transparency=0.35
            b.MouseEnter:Connect(function() b.BackgroundColor3=Color3.fromRGB(130,0,255); s.Transparency=0.05 end)
            b.MouseLeave:Connect(function() b.BackgroundColor3=Color3.fromRGB(22,22,34); s.Transparency=0.35 end)
            b.MouseButton1Click:Connect(function()
                local current=(_G.BZQuickMenuState and _G.BZQuickMenuState.target) or target
                if not current or not current.Parent then
                    if notifyFn then notifyFn("Player invalido",Color3.fromRGB(255,75,75)) end
                    return
                end
                if idx==1 then
                    BZMarkQuickPlayer(current,localPlayer,notifyFn)
                elseif idx==2 then
                    local ok=pcall(function()
                        game:GetService("StarterGui"):SetCore("PromptSendFriendRequest",current)
                    end)
                    if notifyFn then
                        notifyFn(ok and ("Pedido de amizade: "..current.Name) or "Adicionar amigo indisponivel neste ambiente",ok and Color3.fromRGB(80,160,255) or Color3.fromRGB(255,75,75))
                    end
                else
                    local marked=_G.BZMarkedPlayerState and _G.BZMarkedPlayerState.target
                    local t=marked or current
                    local ch=t and t.Character
                    local rt=ch and ch:FindFirstChild("HumanoidRootPart")
                    local myChar=localPlayer and localPlayer.Character
                    local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if rt and myRoot then
                        myRoot.CFrame=rt.CFrame*CFrame.new(0,0,3)
                        if notifyFn then notifyFn("TP -> "..t.Name,Color3.fromRGB(130,0,255)) end
                    elseif notifyFn then
                        notifyFn("Player marcado indisponivel",Color3.fromRGB(255,75,75))
                    end
                end
            end)
        end
        BZQDebug("menu circular criado")
    else
        BZQDebug("menu circular atualizado")
    end
    st.target=target; st.gui.Adornee=root; st.gui.Enabled=true
    BZQDebug("menu circular anexado ao player")
    if not st.conn then
        st.conn=game:GetService("RunService").RenderStepped:Connect(function()
            local s=_G.BZQuickMenuState
            if not s or not s.gui then return end
            local t=s.target
            local ch=t and t.Character
            local hum=ch and ch:FindFirstChildOfClass("Humanoid")
            local rt=ch and ch:FindFirstChild("HumanoidRootPart")
            if not t or not t.Parent or not hum or hum.Health<=0 or not rt then
                BZClearQuickMenu()
                return
            end
            s.gui.Adornee=rt
            if s.a1 and s.a1.Parent~=rt then s.a1.Parent=rt end
        end)
    end
    if notifyFn then notifyFn("Menu rapido: "..target.Name,Color3.fromRGB(80,160,255)) end
    if BZ_QUICK_LINE_ENABLED and localPlayer.Character then
        local myRoot=localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            if not st.a0 then st.a0=Instance.new("Attachment",myRoot) else st.a0.Parent=myRoot end
            if not st.a1 then st.a1=Instance.new("Attachment",root) else st.a1.Parent=root end
            if not st.beam then
                st.beam=Instance.new("Beam")
                st.beam.Name="_BZQuickLine"; st.beam.Width0=0.035; st.beam.Width1=0.035
                st.beam.Color=ColorSequence.new(Color3.fromRGB(255,255,255))
                st.beam.Transparency=NumberSequence.new(0.45)
                st.beam.FaceCamera=true; st.beam.Parent=myRoot
            end
            st.beam.Attachment0=st.a0; st.beam.Attachment1=st.a1
        end
    end
end

local function BZTryQuickMenu(localPlayer,players,camera,parent,notifyFn)
    local now=tick()
    if now-BZ_QUICK_LAST<0.12 then return end
    BZ_QUICK_LAST=now
    BZQDebug("tecla 5 detectada")
    local ok,err=pcall(function()
        local target=BZFindQuickTarget(localPlayer,players,camera)
        if target then
            BZShowQuickMenu(target,localPlayer,parent,notifyFn)
        else
            BZClearQuickMenu()
            if notifyFn then notifyFn("Nenhum player na mira",Color3.fromRGB(45,45,65)) end
        end
    end)
    if not ok then
        BZQDebug("erro no menu rapido: "..tostring(err))
        if notifyFn then notifyFn("Erro no menu rapido",Color3.fromRGB(255,75,75)) end
    end
end

local function BZLockCharacterControls(reason,freezeMouse)
    local st=_G.BZControlLockState
    if not st then st={reasons={}}; _G.BZControlLockState=st end
    st.reasons[reason]=true
    if st.locked then return end
    st.locked=true
    local Players_=game:GetService("Players")
    local UIS_=game:GetService("UserInputService")
    local CAS_=game:GetService("ContextActionService")
    local RS_=game:GetService("RunService")
    local plr=Players_.LocalPlayer
    local char=plr and plr.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    st.mouseIcon=UIS_.MouseIconEnabled; st.mouseBehavior=UIS_.MouseBehavior
    if root then st.root=root; st.rootCF=root.CFrame; st.rootAnchored=root.Anchored; root.Anchored=true end
    if hum then
        st.hum=hum; st.ws=hum.WalkSpeed; st.jp=hum.JumpPower; st.jh=hum.JumpHeight; st.ar=hum.AutoRotate
        hum.WalkSpeed=0; hum.JumpPower=0; hum.JumpHeight=0; hum.AutoRotate=false
        hum:ChangeState(Enum.HumanoidStateType.Physics)
    end
    if freezeMouse then UIS_.MouseIconEnabled=false; UIS_.MouseBehavior=Enum.MouseBehavior.LockCenter end
    CAS_:BindActionAtPriority("_BZ_CharControlBlock",function(_,_,input)
        if input and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.MouseButton2 or input.UserInputType==Enum.UserInputType.MouseButton3) then
            local hub=_G.BZHubMainFrame
            if hub and hub.Parent and hub.Visible then
                local pos=UIS_:GetMouseLocation()
                local ap,as=hub.AbsolutePosition,hub.AbsoluteSize
                if pos.X>=ap.X and pos.X<=ap.X+as.X and pos.Y>=ap.Y and pos.Y<=ap.Y+as.Y then
                    return Enum.ContextActionResult.Pass
                end
            end
        end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+140,
        Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,Enum.KeyCode.Space,
        Enum.KeyCode.LeftShift,Enum.KeyCode.LeftControl,Enum.KeyCode.E,Enum.KeyCode.Q,
        Enum.KeyCode.R,Enum.KeyCode.F,Enum.KeyCode.Z,Enum.KeyCode.X,Enum.KeyCode.C,
        Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four,Enum.KeyCode.Five,
        Enum.UserInputType.MouseButton1,Enum.UserInputType.MouseButton2,Enum.UserInputType.MouseButton3)
    st.conn=RS_.Heartbeat:Connect(function()
        local r=st.root
        if r and r.Parent and st.rootCF then
            r.CFrame=st.rootCF
            r.AssemblyLinearVelocity=Vector3.zero
            r.AssemblyAngularVelocity=Vector3.zero
        end
    end)
end

local function BZUnlockCharacterControls(reason)
    local st=_G.BZControlLockState
    if not st then return end
    st.reasons[reason]=nil
    for _,on in pairs(st.reasons) do if on then return end end
    pcall(function() game:GetService("ContextActionService"):UnbindAction("_BZ_CharControlBlock") end)
    if st.conn then pcall(function() st.conn:Disconnect() end) end
    if st.root and st.root.Parent then st.root.Anchored=st.rootAnchored or false end
    if st.hum and st.hum.Parent then
        st.hum.WalkSpeed=st.ws or 16; st.hum.JumpPower=st.jp or 50
        if st.jh then st.hum.JumpHeight=st.jh end
        st.hum.AutoRotate=st.ar~=false
        st.hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    pcall(function()
        local UIS_=game:GetService("UserInputService")
        UIS_.MouseIconEnabled=st.mouseIcon~=false
        UIS_.MouseBehavior=st.mouseBehavior or Enum.MouseBehavior.Default
    end)
    _G.BZControlLockState=nil
end

local function BZ_BOOTSTRAP_CLEANUP()
    pcall(function()
        if _G.BZ_CLEANUP then _G.BZ_CLEANUP() end
    end)
    _G.BZSession=(_G.BZSession or 0)+1
    _G.BZHubMainFrame=nil
    _G.ZyferBossFarmAimTarget=nil
    BZClearPlayerHighlights()
    BZClearQuickMenu()
    BZClearMarkedPlayer()
    pcall(function()
        local ui=_G.ZyferDivineUI
        if ui then
            if ui.connections then for _,c in ipairs(ui.connections) do if c.Connected then c:Disconnect() end end end
            if ui.root then ui.root:Destroy() end
            _G.ZyferDivineUI=nil
        end
    end)
    BZUnlockCharacterControls("_BZ_FREECAM")
    BZUnlockCharacterControls("_BZ_SPECTATE")
    pcall(function()
        if _G.BZInfJumpConn then _G.BZInfJumpConn:Disconnect(); _G.BZInfJumpConn=nil end
        _G.BZInfJumpAtivo=false
    end)
    pcall(function()
        if _G.FLY_LOOP then _G.FLY_LOOP:Disconnect(); _G.FLY_LOOP=nil end
    end)
    pcall(function()
        local CAS_=game:GetService("ContextActionService")
        CAS_:UnbindAction("_BZ_FCBlockAll")
        CAS_:UnbindAction("_BZ_FCBlockMouse")
        CAS_:UnbindAction("_BZ_SpectBlock")
        CAS_:UnbindAction("_BZQuickMenuKey")
        CAS_:UnbindAction("_BZ_CharControlBlock")
    end)
    pcall(function()
        local Lighting_=game:GetService("Lighting")
        for _,name in ipairs({"VisionEffect"}) do
            local obj=Lighting_:FindFirstChild(name)
            if obj then obj:Destroy() end
        end
    end)
    pcall(function()
        for _,name in ipairs({"_BZv10_ESP","_BZinvischair"}) do
            local obj=workspace:FindFirstChild(name)
            if obj then obj:Destroy() end
        end
    end)
    pcall(function()
        local containers={game.CoreGui}
        if gethui then table.insert(containers,gethui()) end
        local plr=game:GetService("Players").LocalPlayer
        if plr then table.insert(containers,plr:FindFirstChild("PlayerGui")) end
        for _,container in ipairs(containers) do
            if container then
                for _,name in ipairs({"ZyferHub","BezalelHub","TLGui","BZLoader"}) do
                    local obj=container:FindFirstChild(name)
                    if obj then obj:Destroy() end
                end
            end
        end
    end)
    pcall(function()
        local cam=workspace.CurrentCamera
        if cam then
            cam.CameraType=Enum.CameraType.Custom
            cam.FieldOfView=70
        end
    end)
end

BZ_BOOTSTRAP_CLEANUP()

local function BZAddListLayout(parent,padding,fillDirection)
    local layout=Instance.new("UIListLayout",parent)
    layout.SortOrder=Enum.SortOrder.LayoutOrder
    layout.Padding=UDim.new(0,padding or 0)
    if fillDirection then layout.FillDirection=fillDirection end
    return layout
end

local function BZBuildTabButton(tabList,name,order,iconAsset,fallbackText,theme,cornerFn,padFn)
    local button=Instance.new("TextButton",tabList)
    button.Size=UDim2.new(1,0,0,30); button.BackgroundColor3=Color3.new(0,0,0)
    button.BackgroundTransparency=1; button.BorderSizePixel=0
    button.AutoButtonColor=false
    button.Text=""; button.TextSize=11; button.Font=Enum.Font.GothamSemibold
    button.TextColor3=theme.TextMuted; button.TextXAlignment=Enum.TextXAlignment.Left
    button.LayoutOrder=order; cornerFn(button,7)

    local fallback=Instance.new("TextLabel",button)
    fallback.Name="TabIconFallback"; fallback.BackgroundTransparency=1
    fallback.Text=fallbackText or "-"; fallback.TextSize=10; fallback.Font=Enum.Font.GothamBold
    fallback.TextColor3=theme.TabIconIdle; fallback.Size=UDim2.new(0,24,1,0)
    fallback.Position=UDim2.new(0,10,0,0); fallback.TextXAlignment=Enum.TextXAlignment.Center
    fallback.TextYAlignment=Enum.TextYAlignment.Center; fallback.ZIndex=button.ZIndex+1
    local divider=Instance.new("Frame",button)
    divider.Name="TabDivider"; divider.Size=UDim2.new(0,1,0,15)
    divider.Position=UDim2.new(0,42,0.5,-7); divider.BackgroundColor3=theme.Border
    divider.BackgroundTransparency=0.55; divider.BorderSizePixel=0; divider.ZIndex=button.ZIndex+1

    local nameLabel=Instance.new("TextLabel",button)
    nameLabel.Name="TabName"; nameLabel.BackgroundTransparency=1
    nameLabel.Text=name; nameLabel.TextSize=11; nameLabel.Font=Enum.Font.GothamSemibold
    nameLabel.TextColor3=theme.TextMuted; nameLabel.TextXAlignment=Enum.TextXAlignment.Left
    nameLabel.TextYAlignment=Enum.TextYAlignment.Center
    nameLabel.Position=UDim2.new(0,52,0,0); nameLabel.Size=UDim2.new(1,-58,1,0)
    nameLabel.ZIndex=button.ZIndex+1

    if iconAsset and iconAsset~="" then
        local icon=Instance.new("ImageLabel",button)
        icon.Name="TabIcon"; icon.BackgroundTransparency=1
        icon.Size=UDim2.new(0,16,0,16); icon.Position=UDim2.new(0,14,0.5,-8)
        icon.Image="rbxthumb://type=Asset&id="..iconAsset.."&w=150&h=150"
        icon.ImageColor3=theme.TabIconIdle; icon.ImageTransparency=0
        icon.ScaleType=Enum.ScaleType.Fit; icon.ZIndex=button.ZIndex+1
        fallback.TextTransparency=1
    end

    return button
end

local function BZBuildTabPage(scroll,name,order)
    local page=Instance.new("Frame",scroll)
    page.Name=name.."Page"; page.Size=UDim2.new(1,0,0,0); page.BackgroundTransparency=1
    page.Visible=false; page.AutomaticSize=Enum.AutomaticSize.Y; page.LayoutOrder=order
    BZAddListLayout(page,6)
    return page
end

local function BZSetTabVisual(button,on,theme,activeColor,idleColor)
    button.TextColor3=on and Color3.new(1,1,1) or theme.TextMuted
    local nameLabel=button:FindFirstChild("TabName")
    if nameLabel then nameLabel.TextColor3=on and Color3.new(1,1,1) or theme.TextMuted end
    local icon=button:FindFirstChild("TabIcon")
    if icon then icon.ImageColor3=on and activeColor or idleColor end
    local fallback=button:FindFirstChild("TabIconFallback")
    if fallback then
        fallback.TextColor3=on and activeColor or idleColor
    end
    local divider=button:FindFirstChild("TabDivider")
    if divider then
        divider.BackgroundColor3=on and Color3.new(1,1,1) or theme.Border
        divider.BackgroundTransparency=on and 0.25 or 0.55
    end
end

local function BZWireTab(index,tabNames,tabIcons,tabFallbacks,tabList,scroll,pages,tabBtns,theme,cornerFn,padFn,tweenFn,setVisualFn,setTabFn,activeGetter,activeColor,idleColor,hoverColor)
    local name=tabNames[index]
    local button=BZBuildTabButton(tabList,name,index,tabIcons[name],tabFallbacks[name],theme,cornerFn,padFn)
    tabBtns[name]=button
    button.MouseEnter:Connect(function()
        if activeGetter()~=name then
            tweenFn(button,{BackgroundTransparency=0,BackgroundColor3=theme.TabBgHover},0.1):Play()
            setVisualFn(button,true,theme,hoverColor,idleColor)
        end
    end)
    button.MouseLeave:Connect(function()
        if activeGetter()~=name then
            tweenFn(button,{BackgroundTransparency=1},0.1):Play()
            setVisualFn(button,false,theme,activeColor,idleColor)
        end
    end)
    button.MouseButton1Click:Connect(function() setTabFn(name) end)
    pages[name]=BZBuildTabPage(scroll,name,index+1)
end

local function BZWireAllTabs(tabNames,tabIcons,tabFallbacks,tabList,scroll,pages,tabBtns,theme,cornerFn,padFn,tweenFn,setVisualFn,setTabFn,activeGetter,activeColor,idleColor,hoverColor)
    for index=1,#tabNames do
        BZWireTab(index,tabNames,tabIcons,tabFallbacks,tabList,scroll,pages,tabBtns,theme,cornerFn,padFn,tweenFn,setVisualFn,setTabFn,activeGetter,activeColor,idleColor,hoverColor)
    end
end

local function BZSelectTab(name,pages,tabBtns,theme,tweenFn,setVisualFn,activeColor,idleColor,activeBg)
    for pageName,page in pairs(pages) do page.Visible=(pageName==name) end
    for tabName,button in pairs(tabBtns) do
        local on=(tabName==name)
        tweenFn(button,{BackgroundColor3=on and activeBg or Color3.new(0,0,0),BackgroundTransparency=on and 0 or 1},0.15):Play()
        setVisualFn(button,on,theme,activeColor,idleColor)
    end
end

local function BZCreateMouseModal(screenGui)
    local modal=Instance.new("TextButton",screenGui)
    modal.Name="_BZMouseModal"; modal.Size=UDim2.new(1,0,1,0)
    modal.Position=UDim2.new(0,0,0,0); modal.BackgroundTransparency=1
    modal.BorderSizePixel=0; modal.Text=""; modal.ZIndex=0
    modal.Visible=false; modal.Modal=false; modal.AutoButtonColor=false
    return modal
end

local function BZSetHubMouseModal(screenGui,userInputService,on)
    local modal=screenGui and screenGui:FindFirstChild("_BZMouseModal")
    if modal then
        modal.Visible=on
        modal.Modal=on
    end
    pcall(function()
        userInputService.MouseIconEnabled=on
        if on then userInputService.MouseBehavior=Enum.MouseBehavior.Default end
    end)
end

local function BZWireHubCursor(screenGui,userInputService,runService,isVisible)
    local guiService=game:GetService("GuiService")
    local cursor=Instance.new("Frame",screenGui)
    cursor.Name="_BZHubCursor"; cursor.BackgroundColor3=Color3.new(1,1,1)
    cursor.Size=UDim2.new(0,8,0,8); cursor.ZIndex=10000
    cursor.BorderSizePixel=0; cursor.Visible=false
    local cursorCorner=Instance.new("UICorner",cursor)
    cursorCorner.CornerRadius=UDim.new(0,99)
    local cursorStroke=Instance.new("UIStroke",cursor)
    cursorStroke.Color=Color3.new(0,0,0); cursorStroke.Thickness=1; cursorStroke.Transparency=0.15
    runService.RenderStepped:Connect(function()
        local on=isVisible()
        cursor.Visible=on
        if on then
            cursor.BackgroundColor3=(_G.ZyferThemeName=="Zypher Divine") and Color3.fromRGB(246,219,143) or Color3.new(1,1,1)
            local pos=userInputService:GetMouseLocation()
            local inset=guiService:GetGuiInset()
            cursor.Position=UDim2.new(0,pos.X-inset.X-4,0,pos.Y-inset.Y-4)
        end
    end)
end

local function BZWireMainDrag(topBar,main,userInputService,isLocked)
    local state={dragging=false,start=nil,pos=nil}
    topBar.InputBegan:Connect(function(input)
        if isLocked() then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            state.dragging=true; state.start=input.Position; state.pos=main.Position
        end
    end)
    topBar.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then state.dragging=false end
    end)
    userInputService.InputChanged:Connect(function(input)
        if state.dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
            local delta=input.Position-state.start
            main.Position=UDim2.new(state.pos.X.Scale,state.pos.X.Offset+delta.X,state.pos.Y.Scale,state.pos.Y.Offset+delta.Y)
        end
    end)
end

local function BZWireResize(handle,main,userInputService,isLocked,getViewportSizeFn,setHubSizeFn,limits)
    local state={resizing=false,start=nil,size=nil}
    handle.MouseButton1Down:Connect(function()
        if isLocked() then return end
        state.resizing=true
        state.start=userInputService:GetMouseLocation()
        state.size=Vector2.new(main.Size.X.Offset,main.Size.Y.Offset)
    end)
    userInputService.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then state.resizing=false end
    end)
    userInputService.InputChanged:Connect(function(input)
        if state.resizing and input.UserInputType==Enum.UserInputType.MouseMovement then
            local mouse=userInputService:GetMouseLocation()
            local delta=mouse-state.start
            local vp=getViewportSizeFn()
            local maxW=math.min(limits.maxW,math.max(limits.minW,vp.X-limits.margin))
            local maxH=math.min(limits.maxH,math.max(limits.minH,vp.Y-limits.margin))
            setHubSizeFn(math.clamp(state.size.X+delta.X,limits.minW,maxW),math.clamp(state.size.Y+delta.Y,limits.minH,maxH),false)
        end
    end)
end

local function BZBuildCreditsPortfolio(page,theme,cornerFn,strokeFn,labelFn)
    local accent=Color3.fromRGB(130,0,255)
    local accent2=Color3.fromRGB(80,160,255)
    local muted=Color3.fromRGB(148,163,184)

    local function section(parent,title,body,order,color)
        local item=Instance.new("Frame",parent)
        item.Size=UDim2.new(1,0,0,70)
        item.BackgroundColor3=Color3.fromRGB(22,22,34)
        item.BorderSizePixel=0
        item.LayoutOrder=order
        cornerFn(item,9)
        strokeFn(item,color or Color3.fromRGB(55,65,85),0.55)
        local bar=Instance.new("Frame",item)
        bar.Size=UDim2.new(0,3,0.62,0); bar.Position=UDim2.new(0,0,0.19,0)
        bar.BackgroundColor3=color or accent; bar.BorderSizePixel=0
        cornerFn(bar,99)
        local t=labelFn(item,title,12,Enum.Font.GothamBold,theme.Text,1)
        t.Size=UDim2.new(1,-26,0,20); t.Position=UDim2.new(0,14,0,10)
        t.TextXAlignment=Enum.TextXAlignment.Left
        local b=labelFn(item,body,10,Enum.Font.Gotham,muted,1)
        b.Size=UDim2.new(1,-26,0,30); b.Position=UDim2.new(0,14,0,32)
        b.TextWrapped=true; b.TextXAlignment=Enum.TextXAlignment.Left
        return item
    end

    local function chip(parent,text,order)
        local item=Instance.new("Frame",parent)
        item.Size=UDim2.new(0,124,0,32)
        item.BackgroundColor3=Color3.fromRGB(25,26,42)
        item.BorderSizePixel=0
        item.LayoutOrder=order
        cornerFn(item,8)
        strokeFn(item,Color3.fromRGB(55,65,85),0.35)
        local txt=labelFn(item,text,10,Enum.Font.GothamSemibold,theme.Text,1)
        txt.Size=UDim2.new(1,0,1,0)
        txt.TextXAlignment=Enum.TextXAlignment.Center
        return item
    end

    local header=Instance.new("Frame",page)
    header.Size=UDim2.new(1,0,0,132)
    header.BackgroundColor3=Color3.fromRGB(12,14,24)
    header.BorderSizePixel=0
    header.LayoutOrder=1
    cornerFn(header,11)
    strokeFn(header,Color3.fromRGB(255,255,255),0.9)
    local glow=Instance.new("Frame",header)
    glow.Size=UDim2.new(0,5,1,-28); glow.Position=UDim2.new(0,14,0,14)
    glow.BackgroundColor3=accent; glow.BorderSizePixel=0
    cornerFn(glow,99)
    local title=labelFn(header,"Zyfer",28,Enum.Font.GothamBold,theme.Text,1)
    title.Size=UDim2.new(1,-42,0,36); title.Position=UDim2.new(0,30,0,20)
    title.TextXAlignment=Enum.TextXAlignment.Left
    local sub=labelFn(header,"Hub visual e utilitario em evolucao",12,Enum.Font.GothamSemibold,muted,1)
    sub.Size=UDim2.new(1,-42,0,20); sub.Position=UDim2.new(0,30,0,58)
    sub.TextXAlignment=Enum.TextXAlignment.Left
    local badge=Instance.new("Frame",header)
    badge.Size=UDim2.new(0,168,0,25); badge.Position=UDim2.new(0,30,0,90)
    badge.BackgroundColor3=Color3.fromRGB(28,20,48); badge.BorderSizePixel=0
    cornerFn(badge,99); strokeFn(badge,accent,0.55)
    local badgeTxt=labelFn(badge,"v1.0  |  em desenvolvimento",10,Enum.Font.Code,accent2,1)
    badgeTxt.Size=UDim2.new(1,0,1,0); badgeTxt.TextXAlignment=Enum.TextXAlignment.Center

    section(page,"SOBRE","Interface focada em organizacao, visual limpo e controles rapidos para evoluir novas ferramentas.",2,accent)
    section(page,"DESENVOLVIMENTO","Criacao e ajustes: Gusta. Estrutura preparada para novas funcoes sem perder estabilidade.",3,accent2)

    local tech=Instance.new("Frame",page)
    tech.Size=UDim2.new(1,0,0,86)
    tech.BackgroundTransparency=1
    tech.LayoutOrder=4
    local techGrid=Instance.new("UIGridLayout",tech)
    techGrid.CellSize=UDim2.new(0,124,0,32)
    techGrid.CellPadding=UDim2.new(0,10,0,10)
    techGrid.HorizontalAlignment=Enum.HorizontalAlignment.Center
    techGrid.SortOrder=Enum.SortOrder.LayoutOrder
    chip(tech,"Roblox Lua",1); chip(tech,"UI / UX",2); chip(tech,"Sistemas",3)
    chip(tech,"Keybinds",4); chip(tech,"Visual",5); chip(tech,"Zyfer",6)

    local footer=labelFn(page,"</> Zyfer - interface em evolucao",10,Enum.Font.Code,Color3.fromRGB(95,105,125),1)
    footer.Size=UDim2.new(1,0,0,32); footer.LayoutOrder=5
    footer.TextXAlignment=Enum.TextXAlignment.Center
end

local BALL_IMAGE_ID = ""

-- ============================================================
-- FIX 3: TELA DE CARREGAMENTO - transparente + blur
-- ============================================================
local function mostrarLoader(onComplete)
    local cg = gethui and gethui() or game.CoreGui
    local prev = cg:FindFirstChild("BZLoader"); if prev then prev:Destroy() end
    local TS_ = game:GetService("TweenService")
    local Lighting_ = game:GetService("Lighting")

    -- Blur de fundo
    local loaderBlur = Instance.new("BlurEffect", Lighting_)
    loaderBlur.Size = 20

    local LoadGui = Instance.new("ScreenGui")
    LoadGui.Name = "BZLoader"; LoadGui.ResetOnSpawn = false
    LoadGui.IgnoreGuiInset = true; LoadGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    LoadGui.Parent = cg

    -- Fundo semi-transparente (deixa o jogo visivel ao fundo)
    local BG = Instance.new("Frame", LoadGui)
    BG.Size = UDim2.new(1,0,1,0)
    BG.BackgroundColor3 = Color3.fromRGB(8,8,14)
    BG.BackgroundTransparency = 0.22
    BG.BorderSizePixel = 0
    local bgGrad = Instance.new("UIGradient", BG)
    bgGrad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(14,8,28)),ColorSequenceKeypoint.new(1,Color3.fromRGB(6,6,14))}
    bgGrad.Rotation = 135

    local logoF = Instance.new("Frame", BG)
    logoF.Size = UDim2.new(0,250,0,78); logoF.AnchorPoint = Vector2.new(0.5,0.5)
    logoF.Position = UDim2.new(0.5,0,0.39,0); logoF.BackgroundColor3 = Color3.fromRGB(130,0,255)
    logoF.BorderSizePixel = 0; logoF.BackgroundTransparency = 1
    local lcr = Instance.new("UICorner",logoF); lcr.CornerRadius = UDim.new(0,16)
    local lg2 = Instance.new("UIGradient",logoF)
    lg2.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(160,30,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(70,0,160))}
    lg2.Rotation = 135

    local logoTxt = Instance.new("TextLabel",logoF)
    logoTxt.Size = UDim2.new(1,0,0,40); logoTxt.Position = UDim2.new(0,0,0,10)
    logoTxt.BackgroundTransparency = 1; logoTxt.Text = "Zyfer"
    logoTxt.Font = Enum.Font.GothamBold; logoTxt.TextSize = 24; logoTxt.TextColor3 = Color3.new(1,1,1)
    logoTxt.TextXAlignment = Enum.TextXAlignment.Center; logoTxt.TextTransparency = 1

    local versaoTxt = Instance.new("TextLabel",logoF)
    versaoTxt.Size = UDim2.new(1,0,0,18); versaoTxt.Position = UDim2.new(0,0,0,52)
    versaoTxt.BackgroundTransparency = 1; versaoTxt.Text = "v1.0  -  Iniciando sistema..."
    versaoTxt.Font = Enum.Font.Gotham; versaoTxt.TextSize = 11; versaoTxt.TextColor3 = Color3.fromRGB(200,170,255)
    versaoTxt.TextXAlignment = Enum.TextXAlignment.Center; versaoTxt.TextTransparency = 1

    local statusLbl = Instance.new("TextLabel", BG)
    statusLbl.Size = UDim2.new(0,400,0,22); statusLbl.AnchorPoint = Vector2.new(0.5,0)
    statusLbl.Position = UDim2.new(0.5,0,0.585,0); statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "Aguarde..."; statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextSize = 11; statusLbl.TextColor3 = Color3.fromRGB(140,140,170)
    statusLbl.TextXAlignment = Enum.TextXAlignment.Center; statusLbl.TextTransparency = 1

    local pbTrack = Instance.new("Frame", BG)
    pbTrack.Size = UDim2.new(0,400,0,5); pbTrack.AnchorPoint = Vector2.new(0.5,0)
    pbTrack.Position = UDim2.new(0.5,0,0.638,0); pbTrack.BackgroundColor3 = Color3.fromRGB(22,22,40)
    pbTrack.BorderSizePixel = 0; pbTrack.BackgroundTransparency = 1
    local ptc = Instance.new("UICorner",pbTrack); ptc.CornerRadius = UDim.new(0,99)

    local pbFill = Instance.new("Frame", pbTrack)
    pbFill.Size = UDim2.new(0,0,1,0); pbFill.BackgroundColor3 = Color3.fromRGB(130,0,255)
    pbFill.BorderSizePixel = 0
    local pfc = Instance.new("UICorner",pbFill); pfc.CornerRadius = UDim.new(0,99)
    local pgGrad = Instance.new("UIGradient",pbFill)
    pgGrad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(170,40,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(90,0,200))}

    local checks = {
        {0.14,"Verificando workspace..."},
        {0.28,"Conectando servico de jogadores..."},
        {0.44,"Carregando servicos do jogo..."},
        {0.60,"Verificando iluminacao..."},
        {0.74,"Preparando interface visual..."},
        {0.89,"Carregando recursos..."},
        {1.00,"OK  Hub pronto!"},
    }

    task.spawn(function()
        task.wait(0.2)
        -- Fade in do logo
        TS_:Create(logoF,TweenInfo.new(0.4,Enum.EasingStyle.Quad),{BackgroundTransparency=0}):Play()
        TS_:Create(logoTxt,TweenInfo.new(0.4),{TextTransparency=0}):Play()
        TS_:Create(versaoTxt,TweenInfo.new(0.4),{TextTransparency=0}):Play()
        task.wait(0.3)
        TS_:Create(statusLbl,TweenInfo.new(0.3),{TextTransparency=0}):Play()
        TS_:Create(pbTrack,TweenInfo.new(0.3),{BackgroundTransparency=0}):Play()
        task.wait(0.3)
        pcall(function() if not game:IsLoaded() then game.Loaded:Wait() end end)
        for _,c in ipairs(checks) do
            TS_:Create(pbFill,TweenInfo.new(0.3,Enum.EasingStyle.Quad),{Size=UDim2.new(c[1],0,1,0)}):Play()
            statusLbl.Text = c[2]; task.wait(0.38)
        end
        versaoTxt.Text = "OK  Iniciando hub..."; task.wait(0.5)
        -- Fade out do loader
        TS_:Create(BG,TweenInfo.new(0.55,Enum.EasingStyle.Sine),{BackgroundTransparency=1}):Play()
        TS_:Create(loaderBlur,TweenInfo.new(0.55,Enum.EasingStyle.Sine),{Size=0}):Play()
        for _,v in pairs(BG:GetDescendants()) do
            if v:IsA("TextLabel") then TS_:Create(v,TweenInfo.new(0.4),{TextTransparency=1}):Play()
            elseif v:IsA("Frame") then TS_:Create(v,TweenInfo.new(0.4),{BackgroundTransparency=1}):Play() end
        end
        task.wait(0.65); loaderBlur:Destroy(); LoadGui:Destroy(); onComplete()
    end)
end

-- ============================================================
-- ZYFER_MAIN
-- ============================================================
local function ZYFER_MAIN()
local BZ_SID=_G.BZSession
local bzCleanupConnections={}
local function bzTrack(conn)
    if typeof(conn)=="RBXScriptConnection" then
        table.insert(bzCleanupConnections,conn)
    end
    return conn
end
_G.BZ_CLEANUP=function()
    for _,conn in ipairs(bzCleanupConnections) do
        pcall(function()
            if conn.Connected then conn:Disconnect() end
        end)
    end
    bzCleanupConnections={}
    BZClearPlayerHighlights()
    BZClearQuickMenu()
    BZClearMarkedPlayer()
    pcall(function()
        local ui=_G.ZyferDivineUI
        if ui then
            if ui.connections then for _,c in ipairs(ui.connections) do if c.Connected then c:Disconnect() end end end
            if ui.root then ui.root:Destroy() end
            _G.ZyferDivineUI=nil
        end
    end)
    pcall(function()
        if _G.BZInfJumpConn then _G.BZInfJumpConn:Disconnect(); _G.BZInfJumpConn=nil end
        _G.BZInfJumpAtivo=false
    end)
    pcall(function() if _G.FLY_LOOP then _G.FLY_LOOP:Disconnect(); _G.FLY_LOOP=nil end end)
    pcall(function()
        local CAS_=game:GetService("ContextActionService")
        CAS_:UnbindAction("_BZ_FCBlockAll")
        CAS_:UnbindAction("_BZ_FCBlockMouse")
        CAS_:UnbindAction("_BZ_SpectBlock")
        CAS_:UnbindAction("_BZQuickMenuKey")
        CAS_:UnbindAction("_BZ_CharControlBlock")
    end)
    pcall(function()
        for _,name in ipairs({"ZyferHub","BezalelHub","TLGui","BZLoader"}) do
            local obj=(gethui and gethui() or game.CoreGui):FindFirstChild(name)
            if obj then obj:Destroy() end
            local pg=game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                local obj2=pg:FindFirstChild(name)
                if obj2 then obj2:Destroy() end
            end
        end
    end)
    pcall(function()
        for _,name in ipairs({"_BZv10_ESP","_BZinvischair"}) do
            local obj=workspace:FindFirstChild(name)
            if obj then obj:Destroy() end
        end
    end)
    pcall(function()
        local cam=workspace.CurrentCamera
        if cam then cam.CameraType=Enum.CameraType.Custom; cam.FieldOfView=70 end
    end)
end

for _,n in pairs({"ZyferHub","BezalelHub","TLGui"}) do
    local v=game.CoreGui:FindFirstChild(n); if v then v:Destroy() end
    local pg=game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if pg then local v2=pg:FindFirstChild(n); if v2 then v2:Destroy() end end
end
do local o=workspace:FindFirstChild("_BZv10_ESP"); if o then o:Destroy() end end
local c2=workspace:FindFirstChild("_BZinvischair"); if c2 then c2:Destroy() end

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local Lighting=game:GetService("Lighting")
local SoundService=game:GetService("SoundService")
local CAS=game:GetService("ContextActionService")
local Debris=game:GetService("Debris")
local MarketplaceService=game:GetService("MarketplaceService")
local TeleportService=game:GetService("TeleportService")
local LocalPlayer=Players.LocalPlayer
local Camera=workspace.CurrentCamera

-- AIMBOT CONFIG
local AIM_BONE="Head"; local AIM_VEL_PROJ=300; local AIM_MAX_T=0.40
local AIM_PREDICT={{maxDist=40,mult=0.30},{maxDist=100,mult=0.55},{maxDist=200,mult=0.75},{maxDist=math.huge,mult=0.50}}
local function aimGetMult(dist) for _,b in ipairs(AIM_PREDICT) do if dist<b.maxDist then return b.mult end end; return AIM_PREDICT[#AIM_PREDICT].mult end
local aimNPCAtivo=false; local aimFOV=8
local function aimGetPart(char)
    return char:FindFirstChild(AIM_BONE)
        or char:FindFirstChild("HumanoidRootPart")
        or char.PrimaryPart
        or char:FindFirstChild(AIM_BONE,true)
        or char:FindFirstChild("HumanoidRootPart",true)
        or char:FindFirstChildWhichIsA("BasePart",true)
end
local function aimTargetChar(target)
    if typeof(target)~="Instance" then return nil end
    if target:IsA("Player") then return target.Character end
    if target:IsA("Model") then return target end
    return nil
end
local function aimTargetValid(target)
    local char=aimTargetChar(target)
    if not char or not char.Parent or char==LocalPlayer.Character then return nil,nil,nil end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health<=0 then return nil,nil,nil end
    local part=aimGetPart(char)
    if not part or not part.Parent then return nil,nil,nil end
    return char,hum,part
end
local function aimConsiderTarget(target,best,bestA)
    local _,_,part=aimTargetValid(target)
    if not part then return best,bestA end
    local delta=part.Position-Camera.CFrame.Position
    if delta.Magnitude<0.05 then return best,bestA end
    local a=math.deg(math.acos(math.clamp(Camera.CFrame.LookVector:Dot(delta.Unit),-1,1)))
    if a<bestA then return target,a end
    return best,bestA
end
local function aimFindTarget()
    local best,bestA=nil,aimFOV or 8
    for _,p in pairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            best,bestA=aimConsiderTarget(p,best,bestA)
        end
    end
    if aimNPCAtivo then
        for _,obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Humanoid") then
                local model=obj.Parent
                if model and model:IsA("Model") and not Players:GetPlayerFromCharacter(model) then
                    best,bestA=aimConsiderTarget(model,best,bestA)
                end
            end
        end
    end
    return best
end
-- FIX 2: aimbot one-shot lock
local aimLockedTarget = nil
local aimLastPos = nil   -- para detectar teleporte do alvo
_G.ZyferBossFarmAimTarget=nil

local SIDEBAR_W=160
local flyAtivo=false; local invisAtivo=false
local superPuloAtivo=false; local noclipAtivo=false; local noclipConn=nil
local clickTPAtivo=false; local fpsAtivo=false; local fpsConn=nil
local espAtivo=true; local espNome=true; local espHP=true
local espHighlight=true; local espHLOutline=true; local espHLFill=false
local espHLOutlineColor=Color3.fromRGB(255,255,255); local espHLFillColor=Color3.fromRGB(130,0,255)
local espHLOutlineT=0; local espHLFillT=0; local espDist=false; local espDistColor=Color3.fromRGB(255,255,255)
local aimAtivo=false
local tlAtivo=true; local tlModoAtivo=false; local tlHovered=nil; local tlHLs={}; local tlRmbHeld=false
-- FIX 7: limite de distancia do passo fantasma
local maxTlDist = 80   -- studs maximos para o passo fantasma funcionar
local janelaTravada=false; local hubVisible=false; local freecamAtivo=false
local flySpeed=50; local flyBoost=1000
local jumpHeight=120; aimFOV=8; local aimSmooth=0; local flyLoop=nil
local hubW,hubH=600,420
local HUB_MIN_W,HUB_MIN_H=420,300
local HUB_MAX_W,HUB_MAX_H=950,720
local HUB_MARGIN=28
local hubScale=1
local spectateTarget=nil; local spectateConn=nil
local spectOrbitX,spectOrbitY,spectOrbitDist=0,0,10
-- FIX 10: bolinha desativada por padrao
local useBall=false

-- PROXIMITY FLING - variaveis
local flingAtivo      = false
local flingRadius     = 20
local flingOldPos     = nil
local flingFPDH       = workspace.FallenPartsDestroyHeight

local kbGated={fly=false,invis=false,jump=false,freecam=false,noclip=false,fling=false}
local KB={hub=Enum.KeyCode.Backquote,fly=Enum.KeyCode.LeftControl,invis=Enum.KeyCode.LeftControl,
    jump=Enum.KeyCode.Unknown,vision=Enum.KeyCode.Unknown,
    tl=Enum.KeyCode.Unknown,freecam=Enum.KeyCode.Unknown,noclip=Enum.KeyCode.Unknown,
    fling=Enum.KeyCode.Unknown}

local kbEscutando=false; local kbCb=nil; local activeDrag=nil
local tpSaves={}; local allCards={}; local currentTab=""
local mostrarHub,esconderHub,toggleHub,trocarAba,destruirHubDefinitivo
local toggleFreecam; local fcTgtFOV=Camera.FieldOfView
local espCache={}; local espHLCache={}
local updateHLColor,updateEspHL,registerESP
local allToggleSetters={}
local espFolder=Instance.new("Folder",workspace); espFolder.Name="_BZv10_ESP"

local HC={
    Accent=Color3.fromRGB(130,0,255), AccentDark=Color3.fromRGB(90,0,180),
    Background=Color3.fromRGB(14,14,21), Surface=Color3.fromRGB(22,22,34),
    Surface2=Color3.fromRGB(30,30,46), Border=Color3.fromRGB(45,45,65),
    Text=Color3.fromRGB(240,240,255), TextMuted=Color3.fromRGB(140,140,170),
    Success=Color3.fromRGB(80,220,120), Danger=Color3.fromRGB(255,75,75),
    Info=Color3.fromRGB(80,160,255), Green=Color3.fromRGB(55,195,75),
}

local SFX
do
    local function mkS(id,vol)
        local s=Instance.new("Sound"); s.SoundId="rbxassetid://"..id
        s.Volume=vol or 0.4; s.RollOffMaxDistance=0; s.Parent=SoundService; return s
    end
    SFX={click=mkS("6895079853",0.25),toggle=mkS("3200000779",0.40),
         notif=mkS("4590657391",0.30),open=mkS("4239833267",0.50),
         vision=mkS("75158864675813",0.55)}
end
local function pC() pcall(function() SFX.click:Play() end) end
local function pT() pcall(function() SFX.toggle:Play() end) end
local function pN() pcall(function() SFX.notif:Play() end) end
local function pO() pcall(function() SFX.open:Play() end) end

local function getHRP()
    return (LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()):WaitForChild("HumanoidRootPart",5)
end
local function kbNome(kc)
    if kc==Enum.KeyCode.Unknown then return "-- vazio --" end
    return tostring(kc):gsub("Enum%.KeyCode%.","")
end
local function tw(o,p,t,s,d)
    return TweenService:Create(o,TweenInfo.new(t or .18,s or Enum.EasingStyle.Quad,d or Enum.EasingDirection.Out),p)
end
local function corner(p,r) local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 8); return c end
local function pad(p,l,r,t,b)
    local x=Instance.new("UIPadding",p)
    x.PaddingLeft=UDim.new(0,l or 0); x.PaddingRight=UDim.new(0,r or l or 0)
    x.PaddingTop=UDim.new(0,t or l or 0); x.PaddingBottom=UDim.new(0,b or l or 0)
end
local function lbl(parent,txt,size,font,color,bgt)
    local l=Instance.new("TextLabel",parent)
    l.Text=txt; l.TextSize=size or 13; l.Font=font or Enum.Font.Gotham
    l.TextColor3=color or HC.Text; l.BackgroundTransparency=bgt~=nil and bgt or 1
    l.BorderSizePixel=0; return l
end
local function stroke(obj,color,t)
    local s=Instance.new("UIStroke",obj); s.Color=color or HC.Border; s.Thickness=1; s.Transparency=t or 0.5; return s
end

-- ============================================================
-- FIX 3/4/5/6: CAMERA LIVRE
-- ============================================================
do
    local fcConn=nil
    local fcAlteredObjs={}; local fcNomeConns={}
    local fcMiraObjs={}; local fcMiraConn=nil
    local fcCamPos,fcTargetPos=nil,nil
    local fcRotX,fcRotY,fcTgtRotX,fcTgtRotY=0,0,0,0
    local fcCurFOV=Camera.FieldOfView
    -- FIX 5: zoom target
    local fcScrollConn=nil

    -- FIX 4: bloqueia teclas E botoes do mouse no modo camera
    local function fcBlockAll()
        if KB.freecam~=Enum.KeyCode.Unknown then
            CAS:BindActionAtPriority("_BZ_FCBlockAll",function(name,state,obj)
                if state==Enum.UserInputState.Begin and obj.KeyCode==KB.freecam and kbGated.freecam then
                    task.defer(toggleFreecam)
                end
                return Enum.ContextActionResult.Sink
            end,false,Enum.ContextActionPriority.High.Value+100,KB.freecam)
        end
        BZLockCharacterControls("_BZ_FREECAM",true)
    end
    local function fcUnblockAll()
        CAS:UnbindAction("_BZ_FCBlockAll")
        CAS:UnbindAction("_BZ_FCBlockMouse")
        BZUnlockCharacterControls("_BZ_FREECAM")
    end

    local function fcProcessDesc(v)
        if not v or fcAlteredObjs[v] then return end
        local p=v.Parent; local inESP=false
        while p do if p==espFolder then inESP=true; break end; p=p.Parent end
        if inESP then return end
        if v:IsA("BillboardGui") then fcAlteredObjs[v]={type="Enabled",value=v.Enabled}; v.Enabled=false
        elseif v:IsA("TextLabel") or v:IsA("ImageLabel") then fcAlteredObjs[v]={type="Visible",value=v.Visible}; v.Visible=false end
    end
    local function fcApplyToChar(char)
        for _,v in pairs(char:GetDescendants()) do fcProcessDesc(v) end
        local c=char.DescendantAdded:Connect(function(v) if not freecamAtivo then return end; task.wait(); fcProcessDesc(v) end)
        table.insert(fcNomeConns,c)
    end
    local function fcEsconderNomes()
        for _,p in ipairs(Players:GetPlayers()) do
            if p.Character then fcApplyToChar(p.Character) end
            local c=p.CharacterAdded:Connect(function(char)
                if not freecamAtivo then return end; task.wait(0.3); fcApplyToChar(char)
            end)
            table.insert(fcNomeConns,c)
        end
    end
    local function fcRestaurarNomes()
        for _,c in ipairs(fcNomeConns) do c:Disconnect() end; fcNomeConns={}
        for obj,data in pairs(fcAlteredObjs) do
            if obj and obj.Parent then
                if data.type=="Enabled" then obj.Enabled=data.value
                elseif data.type=="Visible" then obj.Visible=data.value end
            end
        end; fcAlteredObjs={}
    end
    local function fcCheckMira(obj)
        if not freecamAtivo or fcMiraObjs[obj] then return end
        if obj:IsA("ImageLabel") or obj:IsA("Frame") then
            if obj.Size.X.Offset>=20 and obj.Size.X.Offset<=200 and obj.BackgroundTransparency==1 then
                fcMiraObjs[obj]=true; obj.Visible=false
            end
        end
    end
    local function fcEsconderMira()
        local gui=LocalPlayer:FindFirstChild("PlayerGui"); if not gui then return end
        for _,v in pairs(gui:GetDescendants()) do fcCheckMira(v) end
        if fcMiraConn then fcMiraConn:Disconnect() end
        fcMiraConn=gui.DescendantAdded:Connect(function(v) task.wait(); if freecamAtivo then fcCheckMira(v) end end)
    end
    local function fcRestaurarMira()
        if fcMiraConn then fcMiraConn:Disconnect(); fcMiraConn=nil end
        for obj in pairs(fcMiraObjs) do if obj and obj.Parent then obj.Visible=true end end; fcMiraObjs={}
    end

    toggleFreecam=function()
        freecamAtivo=not freecamAtivo
        if freecamAtivo then
            fcCamPos=Camera.CFrame.Position; fcTargetPos=fcCamPos
            local x,y=Camera.CFrame:ToOrientation()
            fcRotX,fcRotY=x,y; fcTgtRotX,fcTgtRotY=x,y
            fcCurFOV=Camera.FieldOfView; fcTgtFOV=fcCurFOV
            Camera.CameraType=Enum.CameraType.Scriptable
            Camera.CFrame=CFrame.new(fcCamPos)*(CFrame.Angles(0,fcRotY,0)*CFrame.Angles(fcRotX,0,0))
            fcBlockAll()
            task.defer(function() if freecamAtivo then fcEsconderNomes(); fcEsconderMira() end end)

            -- FIX 5: scroll para zoom
            fcScrollConn=UserInputService.InputChanged:Connect(function(input)
                if not freecamAtivo then return end
                if input.UserInputType==Enum.UserInputType.MouseWheel then
                    fcTgtFOV=math.clamp(fcTgtFOV - input.Position.Z*6, 10, 110)
                end
            end)

            fcConn=RunService.RenderStepped:Connect(function(dt)
                if _G.BZSession~=BZ_SID then fcConn:Disconnect(); return end
                -- FIX 6: LeftCtrl = lento, LeftShift = rapido, padrao = normal
                local spd
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    spd = 5
                elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    spd = 180
                else
                    spd = 32
                end
                local mv=Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+Vector3.new(0,0,-1) end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv+Vector3.new(0,0,1) end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv+Vector3.new(-1,0,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+Vector3.new(1,0,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.E) then mv=mv+Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.Q) then mv=mv+Vector3.new(0,-1,0) end
                if mv.Magnitude>0 then mv=mv.Unit end
                local delta=UserInputService:GetMouseDelta()
                fcTgtRotY=fcTgtRotY-delta.X*0.003; fcTgtRotX=fcTgtRotX-delta.Y*0.003
                fcTgtRotX=math.clamp(fcTgtRotX,-1.5,1.5)
                fcRotX=fcRotX+(fcTgtRotX-fcRotX)*0.055; fcRotY=fcRotY+(fcTgtRotY-fcRotY)*0.055
                local rot=CFrame.Angles(0,fcRotY,0)*CFrame.Angles(fcRotX,0,0)
                fcTargetPos=fcTargetPos+rot:VectorToWorldSpace(mv)*spd*math.clamp(dt,0,0.05)
                fcCamPos=fcCamPos+(fcTargetPos-fcCamPos)*0.18
                fcCurFOV=fcCurFOV+(fcTgtFOV-fcCurFOV)*0.38
                Camera.FieldOfView=fcCurFOV; Camera.CFrame=CFrame.new(fcCamPos)*rot
            end)
        else
            if fcConn then fcConn:Disconnect(); fcConn=nil end
            if fcScrollConn then fcScrollConn:Disconnect(); fcScrollConn=nil end
            Camera.CameraType=Enum.CameraType.Custom; Camera.FieldOfView=70
            fcUnblockAll(); fcRestaurarNomes(); fcRestaurarMira()
        end
    end
end

-- ============================================================
-- ESP
-- ============================================================
do
    local function hpColor(r)
        r=math.clamp(r,0,1)
        if r>=0.5 then return Color3.new(1-(r-.5)/.5,1,0)
        elseif r>=0.25 then local t=(r-.25)/.25; return Color3.new(1,t*.65+(1-t)*.45,0)
        else return Color3.new(1,(r/.25)*.45,0) end
    end
    local function applyHLSettings(h)
        if not h then return end
        h.OutlineColor=espHLOutlineColor
        h.OutlineTransparency=espHLOutline and espHLOutlineT or 1
        h.FillColor=espHLFillColor
        h.FillTransparency=espHLFill and espHLFillT or 1
        h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    end
    updateHLColor=function()
        for _,h in pairs(espHLCache) do
            if h and h.Parent then applyHLSettings(h) end
        end
    end
    local function getPlayerHL(player,char)
        local h=espHLCache[player]
        if h and h.Parent and h.Adornee==char then return h end
        if h then pcall(function() h:Destroy() end) end
        h=char:FindFirstChild("_BZPlayerHighlight")
        if not h or not h:IsA("Highlight") then
            h=Instance.new("Highlight")
            h.Name="_BZPlayerHighlight"
            h.Parent=char
        end
        h.Adornee=char
        espHLCache[player]=h
        return h
    end
    updateEspHL=function()
        if espHighlight then
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer and p.Character then
                    applyHLSettings(getPlayerHL(p,p.Character))
                end
            end
        else
            for p,h in pairs(espHLCache) do if h then pcall(function() h:Destroy() end) end end; espHLCache={}
            BZClearPlayerHighlights()
        end
    end
    local function attachESP(player,char)
        local d=espCache[player]; if not d then return end
        local root=char:WaitForChild("HumanoidRootPart",5); if not root then return end
        d.gui.Adornee=root
        local oldH=espHLCache[player]; if oldH then pcall(function() oldH:Destroy() end); espHLCache[player]=nil end
        if espHighlight then
            applyHLSettings(getPlayerHL(player,char))
        end
    end
    registerESP=function(player)
        if player==LocalPlayer or espCache[player] then return end
        local gui=Instance.new("BillboardGui")
        gui.Name="ESP_"..player.Name; gui.AlwaysOnTop=true
        gui.Size=UDim2.new(0,140,0,58); gui.StudsOffset=Vector3.new(0,2.8,0); gui.LightInfluence=0; gui.Parent=espFolder
        local nLbl=Instance.new("TextLabel",gui); nLbl.Size=UDim2.new(1,0,0,18); nLbl.BackgroundTransparency=1
        nLbl.TextSize=14; nLbl.Font=Enum.Font.GothamBold; nLbl.Text=player.Name
        nLbl.TextStrokeTransparency=0.35; nLbl.TextStrokeColor3=Color3.new(0,0,0)
        local hLbl=Instance.new("TextLabel",gui); hLbl.Size=UDim2.new(1,0,0,16); hLbl.Position=UDim2.new(0,0,0,19)
        hLbl.BackgroundTransparency=1; hLbl.TextSize=13; hLbl.Font=Enum.Font.Gotham; hLbl.Text="0/0"
        hLbl.TextStrokeTransparency=0.4; hLbl.TextStrokeColor3=Color3.new(0,0,0)
        local dLbl=Instance.new("TextLabel",gui); dLbl.Size=UDim2.new(1,0,0,14); dLbl.Position=UDim2.new(0,0,0,37)
        dLbl.BackgroundTransparency=1; dLbl.TextSize=11; dLbl.Font=Enum.Font.Gotham; dLbl.TextColor3=espDistColor
        dLbl.TextStrokeTransparency=0.5; dLbl.TextStrokeColor3=Color3.new(0,0,0)
        espCache[player]={gui=gui,nLbl=nLbl,hLbl=hLbl,dLbl=dLbl}
        if player.Character then task.spawn(attachESP,player,player.Character) end
        player.CharacterAdded:Connect(function(c) task.wait(0.5); attachESP(player,c) end)
    end
    for _,p in ipairs(Players:GetPlayers()) do registerESP(p) end
    Players.PlayerAdded:Connect(registerESP)
    Players.PlayerRemoving:Connect(function(p)
        local d=espCache[p]; if d and d.gui then pcall(function() d.gui:Destroy() end); espCache[p]=nil end
        local h=espHLCache[p]; if h then pcall(function() h:Destroy() end); espHLCache[p]=nil end
        if _G.BZQuickMenuState and _G.BZQuickMenuState.target==p then BZClearQuickMenu() end
        if _G.BZMarkedPlayerState and _G.BZMarkedPlayerState.target==p then BZClearMarkedPlayer() end
    end)
    RunService.RenderStepped:Connect(function()
        if _G.BZSession~=BZ_SID then return end
        local myRoot=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        for player,data in pairs(espCache) do
            local char=player.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
            local root=char and char:FindFirstChild("HumanoidRootPart")
            if not espAtivo or not hum or not root then data.gui.Enabled=false; continue end
            local hp=math.floor(hum.Health); local maxHp=math.max(math.floor(hum.MaxHealth),1)
            local color
            do
                local r=math.clamp(hp/maxHp,0,1)
                if r>=0.5 then color=Color3.new(1-(r-.5)/.5,1,0)
                elseif r>=0.25 then local t=(r-.25)/.25; color=Color3.new(1,t*.65+(1-t)*.45,0)
                else color=Color3.new(1,(r/.25)*.45,0) end
            end
            data.nLbl.Visible=espNome; data.hLbl.Visible=espHP; data.dLbl.Visible=espDist
            if espNome then data.nLbl.Text=player.Name; data.nLbl.TextColor3=color end
            if espHP then data.hLbl.Text=hp.."/"..maxHp; data.hLbl.TextColor3=color end
            if espDist and myRoot then
                data.dLbl.Text=math.floor((root.Position-myRoot.Position).Magnitude).."m"
                data.dLbl.TextColor3=espDistColor
            end
            data.gui.Enabled=true
        end
    end)
end

-- ============================================================
-- FLY
-- ============================================================
local function clearFlyForces()
    local ok,root=pcall(getHRP); if not ok then return end
    for _,v in pairs(root:GetChildren()) do if v.Name=="FlyForce" or v.Name=="FlyGyro" then v:Destroy() end end
end
local function startFly()
    clearFlyForces(); local root=getHRP()
    local gyro=Instance.new("BodyGyro",root); gyro.Name="FlyGyro"; gyro.MaxTorque=Vector3.new(9e9,9e9,9e9); gyro.P=9e4
    local vel=Instance.new("BodyVelocity",root); vel.Name="FlyForce"; vel.MaxForce=Vector3.new(9e9,9e9,9e9)
    if flyLoop then flyLoop:Disconnect() end
    flyLoop=RunService.RenderStepped:Connect(function()
        if _G.BZSession~=BZ_SID then flyLoop:Disconnect(); return end
        if not flyAtivo then return end
        local cam=workspace.CurrentCamera; local m=Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then m=m+cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then m=m-cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then m=m-cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then m=m+cam.CFrame.RightVector end
        local spd=UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and flyBoost or flySpeed
        vel.Velocity=(m.Magnitude>0 and m.Unit or m)*spd; gyro.CFrame=cam.CFrame
    end); _G.FLY_LOOP=flyLoop
end
local function stopFly()
    clearFlyForces(); if flyLoop then flyLoop:Disconnect(); flyLoop=nil end; _G.FLY_LOOP=nil
end

-- INVISIVEL
local function toggleInvis()
    invisAtivo=not invisAtivo
    local char=LocalPlayer.Character
    if not char then invisAtivo=not invisAtivo; return end
    if invisAtivo then
        local hrp=char:FindFirstChild("HumanoidRootPart")
        if not hrp then invisAtivo=false; return end
        local savedPos=hrp.CFrame
        char:MoveTo(Vector3.new(-25.95,84,3537.55))
        task.wait(0.15)
        local Seat=Instance.new("Seat",workspace)
        Seat.Name="_BZinvischair"; Seat.Anchored=false; Seat.CanCollide=false; Seat.Transparency=1
        Seat.Position=Vector3.new(-25.95,84,3537.55)
        local Weld=Instance.new("Weld",Seat); Weld.Part0=Seat
        Weld.Part1=char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        task.wait(); Seat.CFrame=savedPos
    else
        local chair=workspace:FindFirstChild("_BZinvischair"); if chair then chair:Destroy() end
    end
end

local function connectSuperJump(char)
    local hum=char and char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    hum.Jumping:Connect(function(isJumping)
        if not isJumping or not superPuloAtivo then return end
        local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        task.wait(0.01)
        local bv=Instance.new("BodyVelocity",hrp); bv.Name="SuperJumpBV"
        bv.Velocity=Vector3.new(0,jumpHeight,0); bv.MaxForce=Vector3.new(0,math.huge,0); bv.P=math.huge
        Debris:AddItem(bv,0.15)
    end)
end
task.spawn(function()
    if LocalPlayer.Character then connectSuperJump(LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(function(c) task.wait(0.5); connectSuperJump(c) end)
end)

local function toggleNoclip()
    noclipAtivo=not noclipAtivo
    if noclipAtivo then
        noclipConn=RunService.Stepped:Connect(function()
            if _G.BZSession~=BZ_SID then noclipConn:Disconnect(); return end
            local char=LocalPlayer.Character; if not char then return end
            for _,v in pairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=false end end
        end)
    else
        if noclipConn then noclipConn:Disconnect(); noclipConn=nil end
        local char=LocalPlayer.Character
        if char then for _,v in pairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=true end end end
    end
end

local colorFx=Lighting:FindFirstChild("VisionEffect") or Instance.new("ColorCorrectionEffect",Lighting)
colorFx.Name="VisionEffect"
local visionHLs={}; local visionBusy=false
local function ativarVisao()
    if visionBusy then return end; visionBusy=true
    pcall(function() SFX.vision:Play() end)
    for _,p in pairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local h=Instance.new("Highlight",p.Character)
            h.FillColor=Color3.fromRGB(255,0,0); h.FillTransparency=0.3; h.OutlineTransparency=0
            h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; table.insert(visionHLs,h)
        end
    end
    tw(colorFx,{Brightness=-0.3,Contrast=0.5,Saturation=-1},0.5):Play(); task.wait(5)
    tw(colorFx,{Brightness=0,Contrast=0,Saturation=0},0.5):Play()
    for _,h in pairs(visionHLs) do if h then pcall(function() h:Destroy() end) end end
    visionHLs={}; visionBusy=false
end

-- ============================================================
-- PROXIMITY FLING - funcoes
-- ============================================================
local function getFlingNearby()
    local list={}
    local myChar=LocalPlayer.Character; if not myChar then return list end
    local myRoot=myChar:FindFirstChild("HumanoidRootPart"); if not myRoot then return list end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local r=p.Character:FindFirstChild("HumanoidRootPart")
            if r and (r.Position-myRoot.Position).Magnitude<=flingRadius then
                table.insert(list,p)
            end
        end
    end
    return list
end

local function doFling(target)
    local char=LocalPlayer.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=hum and hum.RootPart
    local tChar=target.Character
    if not (char and hum and root and tChar) then return end
    local tHum=tChar:FindFirstChildOfClass("Humanoid")
    local tRoot=tHum and tHum.RootPart
    local tHead=tChar:FindFirstChild("Head")
    local acc=tChar:FindFirstChildOfClass("Accessory")
    local handle=acc and acc:FindFirstChild("Handle")
    if not tChar:FindFirstChildWhichIsA("BasePart") then return end
    if root.Velocity.Magnitude<50 then flingOldPos=root.CFrame end
    if tHead then workspace.CurrentCamera.CameraSubject=tHead
    elseif handle then workspace.CurrentCamera.CameraSubject=handle
    elseif tHum then workspace.CurrentCamera.CameraSubject=tHum end
    local function fpos(part,pos,ang)
        root.CFrame=CFrame.new(part.Position)*pos*ang
        char:SetPrimaryPartCFrame(CFrame.new(part.Position)*pos*ang)
        root.Velocity=Vector3.new(9e7,9e7*10,9e7)
        root.RotVelocity=Vector3.new(9e8,9e8,9e8)
    end
    local function sfpart(part)
        local t=tick(); local angle=0
        repeat
            if root and tHum then
                if part.Velocity.Magnitude<50 then
                    angle=angle+100
                    fpos(part,CFrame.new(0,1.5,0)+tHum.MoveDirection*part.Velocity.Magnitude/1.25,CFrame.Angles(math.rad(angle),0,0)) task.wait()
                    fpos(part,CFrame.new(0,-1.5,0)+tHum.MoveDirection*part.Velocity.Magnitude/1.25,CFrame.Angles(math.rad(angle),0,0)) task.wait()
                    fpos(part,CFrame.new(0,1.5,0)+tHum.MoveDirection,CFrame.Angles(math.rad(angle),0,0)) task.wait()
                    fpos(part,CFrame.new(0,-1.5,0)+tHum.MoveDirection,CFrame.Angles(math.rad(angle),0,0)) task.wait()
                else
                    fpos(part,CFrame.new(0,1.5,tHum.WalkSpeed),CFrame.Angles(math.rad(90),0,0)) task.wait()
                    fpos(part,CFrame.new(0,-1.5,-tHum.WalkSpeed),CFrame.Angles(0,0,0)) task.wait()
                    fpos(part,CFrame.new(0,-1.5,0),CFrame.Angles(math.rad(90),0,0)) task.wait()
                    fpos(part,CFrame.new(0,-1.5,0),CFrame.Angles(0,0,0)) task.wait()
                end
            end
        until t+2<tick() or not flingAtivo
    end
    workspace.FallenPartsDestroyHeight=0/0
    local bv=Instance.new("BodyVelocity"); bv.Velocity=Vector3.new(0,0,0)
    bv.MaxForce=Vector3.new(9e9,9e9,9e9); bv.Parent=root
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated,false)
    if tRoot then sfpart(tRoot) elseif tHead then sfpart(tHead) elseif handle then sfpart(handle) end
    bv:Destroy()
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated,true)
    workspace.CurrentCamera.CameraSubject=hum
    if flingOldPos then
        repeat
            root.CFrame=flingOldPos*CFrame.new(0,.5,0)
            char:SetPrimaryPartCFrame(flingOldPos*CFrame.new(0,.5,0))
            hum:ChangeState("GettingUp")
            for _,p in pairs(char:GetChildren()) do
                if p:IsA("BasePart") then p.Velocity=Vector3.new(); p.RotVelocity=Vector3.new() end
            end
            task.wait()
        until (root.Position-flingOldPos.p).Magnitude<25
        workspace.FallenPartsDestroyHeight=flingFPDH
    end
end

task.spawn(function()
    while _G.BZSession==BZ_SID do
        if flingAtivo then
            local nearby=getFlingNearby()
            for _,p in ipairs(nearby) do
                if not flingAtivo then break end
                pcall(doFling,p)
                task.wait(0.1)
            end
        end
        task.wait(0.5)
    end
end)

-- ============================================================
-- FIX 2: AIMBOT - one-shot lock no RMB press + deteccao de teleporte
-- ============================================================
RunService.RenderStepped:Connect(function()
    if _G.BZSession~=BZ_SID then return end
    if _G.ZyferBossFarmAimTarget then
        local char,hum,aimPart=aimTargetValid(_G.ZyferBossFarmAimTarget)
        if char and hum and aimPart then
            local hrp=char:FindFirstChild("HumanoidRootPart") or aimPart
            local pos=aimPart.Position
            local vel=hrp.AssemblyLinearVelocity
            local dist=(pos-Camera.CFrame.Position).Magnitude
            local tempo=math.min((dist/AIM_VEL_PROJ)*aimGetMult(dist),AIM_MAX_T)
            local tCF=CFrame.new(Camera.CFrame.Position,pos+vel*tempo)
            if aimSmooth<=0 then Camera.CFrame=tCF else Camera.CFrame=Camera.CFrame:Lerp(tCF,0.3/aimSmooth) end
            return
        else
            _G.ZyferBossFarmAimTarget=nil
        end
    end
    if not aimAtivo then aimLockedTarget=nil; aimLastPos=nil; return end
    -- Solta se RMB nao estiver pressionado
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        aimLockedTarget=nil; aimLastPos=nil; return
    end
    if not aimLockedTarget then return end  -- nao busca novo alvo aqui; so faz isso no RMB press

    -- Valida alvo existente (Player ou Model de NPC/Bot/Boss)
    local char,hum,aimPart=aimTargetValid(aimLockedTarget)
    if not char or not hum or not aimPart then
        aimLockedTarget=nil; aimLastPos=nil; return
    end

    -- FIX 2: detecta teleporte do alvo (libera lock se o alvo sumiu longe)
    if aimLastPos then
        local moved=(aimPart.Position-aimLastPos).Magnitude
        if moved>60 then
            aimLockedTarget=nil; aimLastPos=nil; return
        end
    end
    aimLastPos=aimPart.Position

    -- Mira no alvo
    local hrp=char:FindFirstChild("HumanoidRootPart") or aimPart
    local pos=aimPart.Position
    local vel=hrp.AssemblyLinearVelocity
    local dist=(pos-Camera.CFrame.Position).Magnitude
    local tempo=math.min((dist/AIM_VEL_PROJ)*aimGetMult(dist),AIM_MAX_T)
    local tCF=CFrame.new(Camera.CFrame.Position,pos+vel*tempo)
    if aimSmooth<=0 then Camera.CFrame=tCF else Camera.CFrame=Camera.CFrame:Lerp(tCF,0.3/aimSmooth) end
end)

-- ============================================================
-- SPECTATE
-- ============================================================
local function startSpectate(player)
    spectateTarget=player
    BZLockCharacterControls("_BZ_SPECTATE",false)
    Camera.CameraType=Enum.CameraType.Scriptable
    local _,ry,_=Camera.CFrame:ToOrientation()
    spectOrbitY=ry; spectOrbitX=0; spectOrbitDist=10
    if spectateConn then spectateConn:Disconnect() end
    spectateConn=RunService.RenderStepped:Connect(function()
        if _G.BZSession~=BZ_SID then spectateConn:Disconnect(); return end
        if not spectateTarget or spectateTarget~=player then return end
        local tChar=player.Character; if not tChar then return end
        local hrp=tChar:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        local targetPos=hrp.Position+Vector3.new(0,2,0)
        local rot=CFrame.Angles(0,spectOrbitY,0)*CFrame.Angles(spectOrbitX,0,0)
        local camPos=targetPos+rot:VectorToWorldSpace(Vector3.new(0,0,spectOrbitDist))
        Camera.CFrame=CFrame.new(camPos,targetPos)
    end)
end
local function stopSpectate()
    spectateTarget=nil
    if spectateConn then spectateConn:Disconnect(); spectateConn=nil end
    CAS:UnbindAction("_BZ_SpectBlock")
    BZUnlockCharacterControls("_BZ_SPECTATE")
    Camera.CameraType=Enum.CameraType.Custom; Camera.FieldOfView=70
    local myChar=LocalPlayer.Character
    if myChar then
        local hum=myChar:FindFirstChildOfClass("Humanoid")
        if hum then Camera.CameraSubject=hum end
    end
end
UserInputService.InputChanged:Connect(function(input)
    if _G.BZSession~=BZ_SID then return end
    if spectateTarget then
        if input.UserInputType==Enum.UserInputType.MouseMovement then
            spectOrbitY=spectOrbitY-input.Delta.X*0.005
            spectOrbitX=math.clamp(spectOrbitX-input.Delta.Y*0.005,-1.3,1.3)
        end
        if input.UserInputType==Enum.UserInputType.MouseWheel then
            spectOrbitDist=math.clamp(spectOrbitDist-input.Position.Z*2,2,50)
        end
    end
end)

-- TL System
local tlSnd=Instance.new("Sound"); tlSnd.SoundId="rbxassetid://1847323967"; tlSnd.Volume=0.6; tlSnd.Parent=workspace
local tlSGui=Instance.new("ScreenGui"); tlSGui.Name="TLGui"; tlSGui.ResetOnSpawn=false; tlSGui.IgnoreGuiInset=true
local tlNickLbl=Instance.new("TextLabel",tlSGui)
tlNickLbl.AnchorPoint=Vector2.new(1,1); tlNickLbl.Position=UDim2.new(1,-16,1,-48); tlNickLbl.Size=UDim2.new(0,200,0,24)
tlNickLbl.BackgroundTransparency=1; tlNickLbl.TextColor3=Color3.fromRGB(220,35,35); tlNickLbl.TextTransparency=1
tlNickLbl.Font=Enum.Font.GothamBold; tlNickLbl.TextSize=13; tlNickLbl.TextXAlignment=Enum.TextXAlignment.Right
tlNickLbl.TextStrokeTransparency=0.5; tlNickLbl.TextStrokeColor3=Color3.new(0,0,0)
local tlModeLbl=Instance.new("TextLabel",tlSGui)
tlModeLbl.AnchorPoint=Vector2.new(1,1); tlModeLbl.Position=UDim2.new(1,-16,1,-28); tlModeLbl.Size=UDim2.new(0,200,0,18)
tlModeLbl.BackgroundTransparency=1; tlModeLbl.TextColor3=Color3.fromRGB(120,120,120); tlModeLbl.TextTransparency=1
tlModeLbl.Font=Enum.Font.Gotham; tlModeLbl.TextSize=11; tlModeLbl.TextXAlignment=Enum.TextXAlignment.Right
tlModeLbl.Text="[ passo fantasma ativo ]"; tlModeLbl.TextStrokeTransparency=0.6; tlModeLbl.TextStrokeColor3=Color3.new(0,0,0)
task.spawn(function() tlSGui.Parent=LocalPlayer:WaitForChild("PlayerGui") end)
local function tlSetNick(n) tlNickLbl.Text=n or ""; tw(tlNickLbl,{TextTransparency=n and 0 or 1},0.15):Play() end
local function tlSetMode(on) tw(tlModeLbl,{TextTransparency=on and 0 or 1},0.2):Play() end
local function tlRemHL(p) local h=tlHLs[p]; if h then pcall(function() h:Destroy() end); tlHLs[p]=nil end end
local function tlClearAll()
    for p in pairs(tlHLs) do tlRemHL(p) end
    tlHovered=nil; tlModoAtivo=false; tlRmbHeld=false; tlSetNick(nil); tlSetMode(false)
end
RunService.RenderStepped:Connect(function()
    if _G.BZSession~=BZ_SID then return end
    if not tlModoAtivo then return end
    local cam=workspace.CurrentCamera; local sc=Vector2.new(cam.ViewportSize.X/2,cam.ViewportSize.Y/2)
    local best,bestD=nil,math.huge
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LocalPlayer then continue end
        local char=p.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health<=0 then continue end
        local root=char:FindFirstChild("HumanoidRootPart"); if not root then continue end
        local sp,on=cam:WorldToViewportPoint(root.Position); if not on then continue end
        local d=(Vector2.new(sp.X,sp.Y)-sc).Magnitude
        if d<=40 and d<bestD then bestD=d; best=p end
    end
    for p in pairs(tlHLs) do if p~=best then tlRemHL(p) end end
    if best then
        local h=tlHLs[best]; local char=best.Character
        if h and char and h.Adornee~=char then tlRemHL(best); h=nil end
        if not h then
            h=Instance.new("Highlight"); h.OutlineColor=Color3.fromRGB(220,35,35)
            h.FillColor=Color3.fromRGB(220,35,35); h.FillTransparency=0.72; h.OutlineTransparency=0
            h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; h.Adornee=char; h.Parent=char; tlHLs[best]=h
        end
        tlHovered=best; tlSetNick(best.Name)
    else
        tlHovered=nil; tlSetNick(nil)
    end
end)

-- ============================================================
-- MAIN GUI
-- ============================================================
local ScreenGui=Instance.new("ScreenGui")
ScreenGui.Name="ZyferHub"; ScreenGui.ResetOnSpawn=false
ScreenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
ScreenGui.Parent=gethui and gethui() or game.CoreGui
BZCreateMouseModal(ScreenGui)
BZWireHubCursor(ScreenGui,UserInputService,RunService,function() return hubVisible and ScreenGui.Parent~=nil end)

-- BOLINHA
local MiniBall=Instance.new("Frame",ScreenGui)
MiniBall.Size=UDim2.new(0,72,0,72); MiniBall.AnchorPoint=Vector2.new(0,0.5)
MiniBall.Position=UDim2.new(0,20,0.5,-36)
MiniBall.BackgroundColor3=Color3.fromRGB(20,0,50); MiniBall.BorderSizePixel=0
MiniBall.ZIndex=500; MiniBall.Visible=false; corner(MiniBall,99)
local ballGrad=Instance.new("UIGradient",MiniBall)
ballGrad.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(160,30,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(60,0,140))}
ballGrad.Rotation=135
do
    local bs=Instance.new("UIStroke",MiniBall); bs.Color=Color3.fromRGB(160,40,255); bs.Thickness=2.5; bs.Transparency=0.2
    if BALL_IMAGE_ID~="" then
        local ballImg=Instance.new("ImageLabel",MiniBall)
        ballImg.Size=UDim2.new(1,0,1,0); ballImg.BackgroundTransparency=1
        ballImg.Image=BALL_IMAGE_ID; ballImg.ZIndex=501; ballImg.ScaleType=Enum.ScaleType.Fit
        local ic=Instance.new("UICorner",ballImg); ic.CornerRadius=UDim.new(0,99)
    else
        local bzLbl=Instance.new("TextLabel",MiniBall)
        bzLbl.Size=UDim2.new(1,0,1,0); bzLbl.BackgroundTransparency=1
        bzLbl.Text="Z"; bzLbl.Font=Enum.Font.GothamBold; bzLbl.TextSize=24
        bzLbl.TextColor3=Color3.new(1,1,1); bzLbl.ZIndex=501
        bzLbl.TextXAlignment=Enum.TextXAlignment.Center
        bzLbl.TextStrokeTransparency=0.4; bzLbl.TextStrokeColor3=Color3.fromRGB(130,0,255)
    end
    local ballDrag=false; local ballDragStart; local ballStartPos
    local ballClickTime=0; local ballClickN=0
    MiniBall.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            local now=tick()
            if now-ballClickTime<0.38 then ballClickN=ballClickN+1 else ballClickN=1 end
            ballClickTime=now
            if ballClickN>=2 then
                ballClickN=0; MiniBall.Visible=false
                if mostrarHub then mostrarHub() end
            else
                ballDrag=true; ballDragStart=input.Position; ballStartPos=MiniBall.Position
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then ballDrag=false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if ballDrag and input.UserInputType==Enum.UserInputType.MouseMovement then
            local d=input.Position-ballDragStart
            MiniBall.Position=UDim2.new(ballStartPos.X.Scale,ballStartPos.X.Offset+d.X,ballStartPos.Y.Scale,ballStartPos.Y.Offset+d.Y)
        end
    end)
end

local TooltipFrame=Instance.new("Frame",ScreenGui)
TooltipFrame.Size=UDim2.new(0,200,0,0); TooltipFrame.AutomaticSize=Enum.AutomaticSize.Y
TooltipFrame.BackgroundColor3=Color3.fromRGB(18,18,32); TooltipFrame.BorderSizePixel=0
TooltipFrame.ZIndex=300; TooltipFrame.Visible=false; corner(TooltipFrame,6); stroke(TooltipFrame,HC.Border,0.3)
local TooltipLbl=lbl(TooltipFrame,"",11,Enum.Font.Gotham,Color3.fromRGB(180,180,215),1)
TooltipLbl.Size=UDim2.new(1,-16,0,0); TooltipLbl.AutomaticSize=Enum.AutomaticSize.Y
TooltipLbl.TextWrapped=true; TooltipLbl.TextXAlignment=Enum.TextXAlignment.Left; TooltipLbl.ZIndex=301
pad(TooltipLbl,0,0,4,4); pad(TooltipFrame,8,8,6,6)

local TopNotif=Instance.new("Frame",ScreenGui)
TopNotif.Name="_ZyferNotifStack"; TopNotif.AnchorPoint=Vector2.new(1,1)
TopNotif.Size=UDim2.new(0,320,0,230); TopNotif.Position=UDim2.new(1,-18,1,-18)
TopNotif.BackgroundTransparency=1; TopNotif.BorderSizePixel=0; TopNotif.ZIndex=200; TopNotif.Visible=true
local NotifLayout=Instance.new("UIListLayout",TopNotif)
NotifLayout.SortOrder=Enum.SortOrder.LayoutOrder
NotifLayout.Padding=UDim.new(0,8)
NotifLayout.VerticalAlignment=Enum.VerticalAlignment.Bottom

local notifQueue={}; local notifBusy=0
local function showTopNotif(msg,cor)
    pN(); notifBusy=notifBusy+1; cor=cor or HC.Success
    local card=Instance.new("Frame",TopNotif)
    card.Size=UDim2.new(1,0,0,0)
    card.BackgroundColor3=HC.ThemeName=="Zypher Divine" and Color3.fromRGB(255,255,255) or Color3.fromRGB(16,16,28)
    card.BackgroundTransparency=1; card.BorderSizePixel=0; card.ClipsDescendants=true
    card.LayoutOrder=notifBusy; card.ZIndex=200; corner(card,10); stroke(card,cor,0.34)
    local stripe=Instance.new("Frame",card)
    stripe.Size=UDim2.new(0,3,0.62,0); stripe.Position=UDim2.new(0,0,0.19,0)
    stripe.BackgroundColor3=cor; stripe.BackgroundTransparency=1; stripe.BorderSizePixel=0; stripe.ZIndex=201; corner(stripe,4)
    local icon=lbl(card,"!",12,Enum.Font.GothamBold,cor,1)
    icon.Size=UDim2.new(0,28,1,0); icon.Position=UDim2.new(0,9,0,0)
    icon.TextXAlignment=Enum.TextXAlignment.Center; icon.TextTransparency=1; icon.ZIndex=201
    local txt=lbl(card,tostring(msg),11,Enum.Font.GothamSemibold,HC.Text,1)
    txt.Size=UDim2.new(1,-48,1,0); txt.Position=UDim2.new(0,42,0,0)
    txt.TextXAlignment=Enum.TextXAlignment.Left; txt.TextWrapped=true; txt.TextTransparency=1; txt.ZIndex=201
    table.insert(notifQueue,card)
    if #notifQueue>4 then
        local old=table.remove(notifQueue,1)
        if old and old.Parent then old:Destroy() end
    end
    tw(card,{Size=UDim2.new(1,0,0,44),BackgroundTransparency=0.06},0.22,Enum.EasingStyle.Quart):Play()
    tw(stripe,{BackgroundTransparency=0},0.16):Play()
    tw(icon,{TextTransparency=0},0.16):Play()
    tw(txt,{TextTransparency=0},0.16):Play()
    task.delay(3,function()
        if not card.Parent then return end
        for i=#notifQueue,1,-1 do
            if notifQueue[i]==card then table.remove(notifQueue,i); break end
        end
        tw(card,{Size=UDim2.new(1,0,0,0),BackgroundTransparency=1},0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.In):Play()
        tw(stripe,{BackgroundTransparency=1},0.14):Play()
        tw(icon,{TextTransparency=1},0.14):Play()
        tw(txt,{TextTransparency=1},0.14):Play()
        task.delay(0.25,function() if card.Parent then card:Destroy() end end)
    end)
end

CAS:BindActionAtPriority("_BZQuickMenuKey",function(_,state)
    if _G.BZSession~=BZ_SID then return Enum.ContextActionResult.Pass end
    if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
    if state==Enum.UserInputState.Begin and not UserInputService:IsKeyDown(Enum.KeyCode.Z) then
        BZTryQuickMenu(LocalPlayer,Players,Camera,ScreenGui,showTopNotif)
    end
    return Enum.ContextActionResult.Sink
end,false,Enum.ContextActionPriority.High.Value+20,Enum.KeyCode.Five)

-- FPS display
local FpsDisplay=Instance.new("Frame",ScreenGui)
FpsDisplay.Size=UDim2.new(0,100,0,34); FpsDisplay.AnchorPoint=Vector2.new(0,0)
FpsDisplay.Position=UDim2.new(0.5,-50,0,14)
FpsDisplay.BackgroundColor3=Color3.fromRGB(12,12,20); FpsDisplay.BackgroundTransparency=0.08
FpsDisplay.BorderSizePixel=0; FpsDisplay.ZIndex=100; FpsDisplay.Visible=false; corner(FpsDisplay,9)
local fpsNormalStroke=stroke(FpsDisplay,HC.Accent,0.4)
local fpsDragStroke=stroke(FpsDisplay,Color3.fromRGB(255,210,0),1)
local FpsIconLbl=lbl(FpsDisplay,"FPS",9,Enum.Font.GothamBold,HC.TextMuted,1)
FpsIconLbl.Size=UDim2.new(0,34,1,0); FpsIconLbl.TextXAlignment=Enum.TextXAlignment.Center
local FpsValueLbl=lbl(FpsDisplay,"--",15,Enum.Font.GothamBold,HC.Accent,1)
FpsValueLbl.Size=UDim2.new(1,-36,1,0); FpsValueLbl.Position=UDim2.new(0,34,0,0)
FpsValueLbl.TextXAlignment=Enum.TextXAlignment.Left
local FpsDot=Instance.new("Frame",FpsDisplay); FpsDot.Size=UDim2.new(0,6,0,6); FpsDot.AnchorPoint=Vector2.new(1,0.5)
FpsDot.Position=UDim2.new(1,-5,0.5,0); FpsDot.BackgroundColor3=HC.Success; FpsDot.BorderSizePixel=0; corner(FpsDot,99)
do
    local fpsDraggable=false; local fpsDragActive=false
    local fpsDragStart; local fpsDragStartPos
    local fpsClickTime=0; local fpsClickCount=0
    FpsDisplay.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            local now=tick()
            if now-fpsClickTime<0.38 then fpsClickCount=fpsClickCount+1 else fpsClickCount=1 end
            fpsClickTime=now
            if fpsClickCount>=2 then
                fpsClickCount=0; fpsDraggable=not fpsDraggable; fpsDragActive=false
                fpsDragStroke.Transparency=fpsDraggable and 0 or 1
                fpsNormalStroke.Color=fpsDraggable and Color3.fromRGB(255,210,0) or HC.Accent
            elseif fpsDraggable then
                fpsDragActive=true; fpsDragStart=input.Position; fpsDragStartPos=FpsDisplay.Position
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then fpsDragActive=false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if fpsDragActive and input.UserInputType==Enum.UserInputType.MouseMovement then
            local d=input.Position-fpsDragStart
            FpsDisplay.Position=UDim2.new(fpsDragStartPos.X.Scale,fpsDragStartPos.X.Offset+d.X,fpsDragStartPos.Y.Scale,fpsDragStartPos.Y.Offset+d.Y)
        end
    end)
end

local Main=Instance.new("Frame",ScreenGui)
Main.Name="Main"; Main.AnchorPoint=Vector2.new(0.5,0.5)
Main.Size=UDim2.new(0,hubW,0,hubH); Main.Position=UDim2.new(0.5,0,0.5,0)
Main.BackgroundColor3=HC.Background; Main.BorderSizePixel=0; Main.ClipsDescendants=true; corner(Main,18)
_G.BZHubMainFrame=Main
local MainScale=Instance.new("UIScale",Main)
MainScale.Scale=1

local Sidebar=Instance.new("Frame",Main)
Sidebar.Size=UDim2.new(0,SIDEBAR_W,1,0); Sidebar.BackgroundColor3=HC.Surface; Sidebar.BorderSizePixel=0
local SepLine=Instance.new("Frame",Main)
SepLine.Size=UDim2.new(0,1,1,0); SepLine.Position=UDim2.new(0,SIDEBAR_W,0,0)
SepLine.BackgroundColor3=HC.Border; SepLine.BackgroundTransparency=0.4; SepLine.BorderSizePixel=0

local LogoBG=Instance.new("Frame",Sidebar)
LogoBG.Size=UDim2.new(1,0,0,62); LogoBG.Position=UDim2.new(0,0,0,0)
LogoBG.BorderSizePixel=0; LogoBG.BackgroundColor3=HC.Accent; LogoBG.ZIndex=2
LogoBG.ClipsDescendants=true
local LGrad=Instance.new("UIGradient",LogoBG)
LGrad.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,HC.Accent),ColorSequenceKeypoint.new(1,HC.AccentDark)}
LGrad.Rotation=90
do
    local mark=Instance.new("Frame",LogoBG)
    mark.Size=UDim2.new(0,4,0,34); mark.Position=UDim2.new(0,12,0.5,-17)
    mark.BackgroundColor3=Color3.new(1,1,1); mark.BackgroundTransparency=0.12
    mark.BorderSizePixel=0; mark.ZIndex=3; corner(mark,99)
    local t=lbl(LogoBG,"Zyfer",18,Enum.Font.GothamBold,Color3.new(1,1,1),1)
    t.Size=UDim2.new(1,-36,0,24); t.Position=UDim2.new(0,24,0,12)
    t.TextXAlignment=Enum.TextXAlignment.Left; t.ZIndex=4
    local s=lbl(LogoBG,"Control Hub",10,Enum.Font.GothamSemibold,Color3.fromRGB(220,205,255),1)
    s.Size=UDim2.new(1,-36,0,14); s.Position=UDim2.new(0,24,0,36)
    s.TextXAlignment=Enum.TextXAlignment.Left; s.ZIndex=4
end

local SearchBox=Instance.new("Frame",Sidebar)
SearchBox.Size=UDim2.new(1,-14,0,27); SearchBox.Position=UDim2.new(0,7,0,68)
SearchBox.BackgroundColor3=HC.Surface2; SearchBox.BorderSizePixel=0; corner(SearchBox,7)
local searchIco=lbl(SearchBox,"/",11,Enum.Font.GothamBold,HC.TextMuted,1)
searchIco.Size=UDim2.new(0,24,1,0); searchIco.TextXAlignment=Enum.TextXAlignment.Center
local SearchInput=Instance.new("TextBox",SearchBox)
SearchInput.Size=UDim2.new(1,-28,1,-4); SearchInput.Position=UDim2.new(0,24,0,2)
SearchInput.BackgroundTransparency=1; SearchInput.BorderSizePixel=0
SearchInput.PlaceholderText="Pesquisar..."; SearchInput.PlaceholderColor3=HC.TextMuted
SearchInput.Text=""; SearchInput.TextSize=11; SearchInput.Font=Enum.Font.Gotham
SearchInput.TextColor3=HC.Text; SearchInput.TextXAlignment=Enum.TextXAlignment.Left; SearchInput.ClearTextOnFocus=false
SearchInput.Focused:Connect(function() tw(SearchBox,{BackgroundColor3=Color3.fromRGB(38,28,58)},0.15):Play() end)
SearchInput.FocusLost:Connect(function() tw(SearchBox,{BackgroundColor3=HC.Surface2},0.15):Play() end)

local TabList=Instance.new("ScrollingFrame",Sidebar)
TabList.Size=UDim2.new(1,0,1,-152); TabList.Position=UDim2.new(0,0,0,102); TabList.BackgroundTransparency=1
TabList.BorderSizePixel=0; TabList.CanvasSize=UDim2.new(0,0,0,0); TabList.AutomaticCanvasSize=Enum.AutomaticSize.Y
TabList.ScrollBarThickness=3; TabList.ScrollBarImageColor3=HC.Accent; TabList.ScrollBarImageTransparency=0.25
TabList.ScrollingDirection=Enum.ScrollingDirection.Y; TabList.VerticalScrollBarInset=Enum.ScrollBarInset.ScrollBar
TabList.ClipsDescendants=true
BZAddListLayout(TabList,2)
pad(TabList,6,6,4,4)

local StatusBar=Instance.new("Frame",Sidebar)
StatusBar.Size=UDim2.new(1,0,0,44); StatusBar.Position=UDim2.new(0,0,1,-44)
StatusBar.BackgroundColor3=HC.Surface2; StatusBar.BorderSizePixel=0
local StatusDot=Instance.new("Frame",StatusBar)
StatusDot.Size=UDim2.new(0,7,0,7); StatusDot.Position=UDim2.new(0,11,0,8)
StatusDot.BackgroundColor3=HC.Success; StatusDot.BorderSizePixel=0; corner(StatusDot,99)
local StatusLbl=lbl(StatusBar,"Conectado",10,nil,HC.TextMuted,1)
StatusLbl.Size=UDim2.new(1,-26,0,14); StatusLbl.Position=UDim2.new(0,24,0,4); StatusLbl.TextXAlignment=Enum.TextXAlignment.Left
local TickerCont=Instance.new("Frame",StatusBar)
TickerCont.Size=UDim2.new(1,-8,0,18); TickerCont.Position=UDim2.new(0,4,0,22)
TickerCont.BackgroundTransparency=1; TickerCont.ClipsDescendants=true; TickerCont.BorderSizePixel=0
local TickerLbl=lbl(TickerCont,"",10,nil,Color3.fromRGB(160,130,220),1)
TickerLbl.Size=UDim2.new(0,900,1,0); TickerLbl.TextXAlignment=Enum.TextXAlignment.Left
TickerLbl.TextTransparency=1; TickerLbl.BorderSizePixel=0

task.spawn(function()
    local ok,info=pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
    local gameName=(ok and info and info.Name) or "Jogo Desconhecido"
    TickerLbl.Text=gameName.."   *   "..gameName.."   *   "..gameName.."   *   "
    task.wait(0.2)
    local pos=0
    RunService.RenderStepped:Connect(function(dt)
        if _G.BZSession~=BZ_SID then return end
        if not TickerLbl.Parent then return end
        pos=pos-28*dt
        local hw=TickerLbl.TextBounds.X/3
        if hw>0 and pos<-hw then pos=0 end
        TickerLbl.Position=UDim2.new(0,math.floor(pos),0,0)
    end)
    while TickerLbl.Parent and _G.BZSession==BZ_SID do
        tw(TickerLbl,{TextTransparency=0},0.75,Enum.EasingStyle.Sine):Play()
        task.wait(3.8)
        tw(TickerLbl,{TextTransparency=1},0.75,Enum.EasingStyle.Sine):Play()
        task.wait(1.5)
    end
end)

local ContentArea=Instance.new("Frame",Main)
ContentArea.Size=UDim2.new(1,-SIDEBAR_W,1,0); ContentArea.Position=UDim2.new(0,SIDEBAR_W,0,0)
ContentArea.BackgroundTransparency=1

local TopBar=Instance.new("Frame",ContentArea)
TopBar.Size=UDim2.new(1,0,0,48); TopBar.BackgroundColor3=HC.Surface; TopBar.BorderSizePixel=0
local TopAccent=Instance.new("Frame",TopBar)
TopAccent.Size=UDim2.new(1,0,0,2); TopAccent.Position=UDim2.new(0,0,1,-2); TopAccent.BackgroundColor3=HC.Accent; TopAccent.BorderSizePixel=0
local TAGrad=Instance.new("UIGradient",TopAccent)
TAGrad.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,HC.Accent),ColorSequenceKeypoint.new(1,Color3.fromRGB(14,14,21))}
local TabTitle=lbl(TopBar,"Visual",15,Enum.Font.GothamBold,HC.Text,1)
TabTitle.Size=UDim2.new(0,160,1,-4); TabTitle.Position=UDim2.new(0,14,0,2); TabTitle.TextXAlignment=Enum.TextXAlignment.Left
local BtnClose=Instance.new("TextButton",TopBar)
BtnClose.Size=UDim2.new(0,26,0,26); BtnClose.Position=UDim2.new(1,-34,0.5,-13)
BtnClose.BackgroundColor3=HC.Danger; BtnClose.BorderSizePixel=0; BtnClose.Text="x"
BtnClose.TextColor3=Color3.new(1,1,1); BtnClose.TextSize=13; BtnClose.Font=Enum.Font.GothamBold; BtnClose.ZIndex=5; corner(BtnClose,6)
local BtnMin=Instance.new("TextButton",TopBar)
BtnMin.Size=UDim2.new(0,26,0,26); BtnMin.Position=UDim2.new(1,-66,0.5,-13)
BtnMin.BackgroundColor3=HC.Green; BtnMin.BorderSizePixel=0; BtnMin.Text="-"
BtnMin.TextColor3=Color3.new(1,1,1); BtnMin.TextSize=15; BtnMin.Font=Enum.Font.GothamBold; BtnMin.ZIndex=5; corner(BtnMin,6)
BtnClose.MouseEnter:Connect(function() tw(BtnClose,{BackgroundColor3=Color3.fromRGB(255,60,80)},0.1):Play() end)
BtnClose.MouseLeave:Connect(function() tw(BtnClose,{BackgroundColor3=HC.Danger},0.1):Play() end)
BtnMin.MouseEnter:Connect(function() tw(BtnMin,{BackgroundColor3=Color3.fromRGB(80,230,100)},0.1):Play() end)
BtnMin.MouseLeave:Connect(function() tw(BtnMin,{BackgroundColor3=HC.Green},0.1):Play() end)

local ScrollClip=Instance.new("Frame",ContentArea)
ScrollClip.Size=UDim2.new(1,0,1,-48); ScrollClip.Position=UDim2.new(0,0,0,48)
ScrollClip.BackgroundTransparency=1; ScrollClip.ClipsDescendants=true; ScrollClip.BorderSizePixel=0

local Scroll=Instance.new("ScrollingFrame",ScrollClip)
Scroll.Size=UDim2.new(1,-20,1,-12); Scroll.Position=UDim2.new(0,0,0,5)
Scroll.BackgroundTransparency=1; Scroll.BorderSizePixel=0; Scroll.ScrollBarThickness=3
Scroll.ScrollBarImageColor3=HC.Accent; Scroll.CanvasSize=UDim2.new(0,0,0,0); Scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
BZAddListLayout(Scroll,0)
pad(Scroll,10,16,10,16)

local ResizeHandle=Instance.new("TextButton",Main)
ResizeHandle.Size=UDim2.new(0,22,0,22); ResizeHandle.AnchorPoint=Vector2.new(1,1); ResizeHandle.Position=UDim2.new(1,0,1,0)
ResizeHandle.BackgroundTransparency=1; ResizeHandle.Text="o"; ResizeHandle.TextColor3=HC.TextMuted
ResizeHandle.TextSize=13; ResizeHandle.Font=Enum.Font.GothamBold; ResizeHandle.BorderSizePixel=0; ResizeHandle.ZIndex=12

local function getViewportSize()
    local cam=workspace.CurrentCamera or Camera
    if cam and cam.ViewportSize.X>0 and cam.ViewportSize.Y>0 then
        return cam.ViewportSize
    end
    return Vector2.new(1280,720)
end

local function getFitScale(w,h)
    local vp=getViewportSize()
    local maxW=math.max(vp.X-HUB_MARGIN,320)
    local maxH=math.max(vp.Y-HUB_MARGIN,260)
    return math.clamp(math.min(maxW/math.max(w,1),maxH/math.max(h,1)),0.62,1)
end

local function applyResponsiveLayout()
    hubW=math.clamp(hubW,HUB_MIN_W,HUB_MAX_W)
    hubH=math.clamp(hubH,HUB_MIN_H,HUB_MAX_H)
    hubScale=getFitScale(hubW,hubH)
    MainScale.Scale=hubScale
end

local function setHubSize(w,h,animated,time,style)
    hubW=math.clamp(w,HUB_MIN_W,HUB_MAX_W)
    hubH=math.clamp(h,HUB_MIN_H,HUB_MAX_H)
    applyResponsiveLayout()
    local goal={Size=UDim2.new(0,hubW,0,hubH)}
    if animated then
        tw(Main,goal,time or 0.22,style or Enum.EasingStyle.Quad):Play()
    else
        Main.Size=goal.Size
    end
end

applyResponsiveLayout()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if ScreenGui.Parent then applyResponsiveLayout() end
    end)
end

-- ============================================================
-- COMPONENT BUILDERS
-- ============================================================
local function criarHeader(pai,texto,ordem)
    local F=Instance.new("Frame",pai); F.Size=UDim2.new(1,0,0,28); F.BackgroundTransparency=1; F.LayoutOrder=ordem
    local L=lbl(F,texto,11,Enum.Font.GothamBold,HC.Accent,1)
    L.Size=UDim2.new(1,-8,1,0); L.Position=UDim2.new(0,4,0,0); L.TextXAlignment=Enum.TextXAlignment.Left
    local Line=Instance.new("Frame",F); Line.Size=UDim2.new(1,-8,0,1); Line.Position=UDim2.new(0,4,1,-2)
    Line.BackgroundColor3=HC.Accent; Line.BackgroundTransparency=0.7; Line.BorderSizePixel=0; return F
end
local function criarPill(parent,estado)
    local Pill=Instance.new("Frame",parent); Pill.Size=UDim2.new(0,42,0,22); Pill.AnchorPoint=Vector2.new(1,0.5)
    Pill.Position=UDim2.new(1,-8,0.5,0); Pill.BackgroundColor3=estado and HC.Accent or HC.Border; Pill.BorderSizePixel=0; corner(Pill,99); Pill.ZIndex=4
    local Dot=Instance.new("Frame",Pill); Dot.Size=UDim2.new(0,16,0,16)
    Dot.Position=estado and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    Dot.BackgroundColor3=Color3.new(1,1,1); Dot.BorderSizePixel=0; corner(Dot,99)
    local function setP(on)
        tw(Pill,{BackgroundColor3=on and HC.Accent or HC.Border},0.14):Play()
        tw(Dot,{Position=on and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)},0.14):Play()
    end
    return Pill,Dot,setP
end
local function criarKBBtn(parent,kbId,rightOff)
    local Btn=Instance.new("TextButton",parent)
    Btn.Size=UDim2.new(0,80,0,22); Btn.AnchorPoint=Vector2.new(1,0.5); Btn.Position=UDim2.new(1,rightOff or -56,0.5,0)
    Btn.BackgroundColor3=HC.Surface2; Btn.BorderSizePixel=0; Btn.Text=kbNome(KB[kbId])
    Btn.TextColor3=HC.TextMuted; Btn.TextSize=10; Btn.Font=Enum.Font.GothamBold; Btn.ZIndex=10; corner(Btn,5); stroke(Btn,HC.Border,0.4)
    local function update(kc) KB[kbId]=kc; Btn.Text=kbNome(kc); Btn.TextColor3=kc==Enum.KeyCode.Unknown and HC.TextMuted or HC.Text end
    Btn.MouseButton1Click:Connect(function()
        if kbEscutando then return end; pC(); Btn.Text="Pressione..."; Btn.TextColor3=HC.Accent
        kbEscutando=true; kbCb=function(kc) update(kc) end
    end)
    Btn.MouseButton2Click:Connect(function() update(Enum.KeyCode.Unknown) end)
    return Btn
end
local function criarInfoBtn(titleRow,texto)
    if not texto or texto=="" then return nil end
    local btn=Instance.new("TextButton",titleRow)
    btn.Size=UDim2.new(0,17,0,17); btn.BackgroundColor3=HC.Surface2; btn.BorderSizePixel=0
    btn.Text="?"; btn.TextColor3=HC.TextMuted; btn.TextSize=9; btn.Font=Enum.Font.GothamBold
    btn.ZIndex=10; corner(btn,5); btn.LayoutOrder=99
    local hT
    btn.MouseEnter:Connect(function()
        hT=task.delay(0.45,function()
            if not btn.Parent then return end; TooltipLbl.Text=texto
            local m=UserInputService:GetMouseLocation()
            TooltipFrame.Position=UDim2.new(0,m.X+14,0,m.Y-8); TooltipFrame.Visible=true
        end)
    end)
    btn.MouseLeave:Connect(function() if hT then task.cancel(hT) end; TooltipFrame.Visible=false end)
    btn.MouseMoved:Connect(function(x,y) if TooltipFrame.Visible then TooltipFrame.Position=UDim2.new(0,x+14,0,y-8) end end)
    return btn
end
local function baseCard(pai,h,ordem)
    local F=Instance.new("Frame",pai); F.Size=UDim2.new(1,0,0,h or 50)
    F.BackgroundColor3=HC.Surface2; F.BorderSizePixel=0; F.LayoutOrder=ordem or 0; corner(F,8)
    local Bar=Instance.new("Frame",F); Bar.Size=UDim2.new(0,3,0.6,0); Bar.Position=UDim2.new(0,0,0.2,0)
    Bar.BackgroundColor3=HC.Accent; Bar.BackgroundTransparency=1; Bar.BorderSizePixel=0; corner(Bar,99)
    F.MouseEnter:Connect(function() tw(F,{BackgroundColor3=Color3.fromRGB(37,37,55)},0.1):Play() end)
    F.MouseLeave:Connect(function() tw(F,{BackgroundColor3=HC.Surface2},0.1):Play() end)
    return F,Bar
end
local function makeTitleRow(parent,text,rightReserved,yOff)
    local row=Instance.new("Frame",parent); row.BackgroundTransparency=1
    row.Position=UDim2.new(0,12,0,yOff or 8); row.Size=UDim2.new(1,-(rightReserved or 60)-12,0,18)
    local rl=Instance.new("UIListLayout",row)
    rl.FillDirection=Enum.FillDirection.Horizontal; rl.VerticalAlignment=Enum.VerticalAlignment.Center
    rl.Padding=UDim.new(0,4); rl.SortOrder=Enum.SortOrder.LayoutOrder
    local nlbl=Instance.new("TextLabel",row); nlbl.BackgroundTransparency=1; nlbl.Text=text
    nlbl.Font=Enum.Font.GothamSemibold; nlbl.TextSize=13; nlbl.TextColor3=HC.Text; nlbl.LayoutOrder=1
    nlbl.AutomaticSize=Enum.AutomaticSize.X; nlbl.Size=UDim2.new(0,0,0,18); nlbl.TextXAlignment=Enum.TextXAlignment.Left; nlbl.BorderSizePixel=0
    return row,nlbl
end

local function criarRGBPicker(parent,label,defaultColor,onColorChanged,ordem)
    local curH,curS,curV=Color3.toHSV(defaultColor)
    local Card=Instance.new("Frame",parent)
    Card.Size=UDim2.new(1,-8,0,104)
    Card.BackgroundColor3=Color3.fromRGB(18,18,30); Card.BorderSizePixel=0; Card.LayoutOrder=ordem; corner(Card,7)
    local LBL=lbl(Card,label,9,Enum.Font.GothamSemibold,HC.TextMuted,1)
    LBL.Size=UDim2.new(1,-46,0,14); LBL.Position=UDim2.new(0,8,0,5); LBL.TextXAlignment=Enum.TextXAlignment.Left
    local Preview=Instance.new("Frame",Card)
    Preview.Size=UDim2.new(0,30,0,30); Preview.AnchorPoint=Vector2.new(1,0)
    Preview.Position=UDim2.new(1,-6,0,5); Preview.BackgroundColor3=defaultColor
    Preview.BorderSizePixel=0; corner(Preview,6); stroke(Preview,Color3.new(1,1,1),0.5)
    local hexLbl=lbl(Card,"",8,nil,HC.TextMuted,1)
    hexLbl.Size=UDim2.new(1,-16,0,11); hexLbl.Position=UDim2.new(0,8,0,89)
    hexLbl.TextXAlignment=Enum.TextXAlignment.Left
    local sGradRef,vGradRef
    local function makeRGBSlider(yPos,sliderLabel,initRatio,onDragFn)
        local lf=lbl(Card,sliderLabel,8,nil,HC.TextMuted,1)
        lf.Size=UDim2.new(0,14,0,10); lf.Position=UDim2.new(0,8,0,yPos+2)
        lf.TextXAlignment=Enum.TextXAlignment.Center
        local Track=Instance.new("Frame",Card)
        Track.Size=UDim2.new(1,-78,0,10); Track.Position=UDim2.new(0,26,0,yPos)
        Track.BackgroundColor3=Color3.new(1,1,1); Track.BorderSizePixel=0; corner(Track,99)
        local grad=Instance.new("UIGradient",Track)
        local Mark=Instance.new("Frame",Track)
        Mark.Size=UDim2.new(0,14,0,14); Mark.AnchorPoint=Vector2.new(0.5,0.5)
        Mark.Position=UDim2.new(initRatio,0,0.5,0); Mark.BackgroundColor3=Color3.new(1,1,1)
        Mark.BorderSizePixel=0; Mark.ZIndex=3; corner(Mark,99); stroke(Mark,Color3.fromRGB(60,60,80),0.4)
        local SBtn=Instance.new("TextButton",Track)
        SBtn.Size=UDim2.new(1,0,0,28); SBtn.Position=UDim2.new(0,0,0.5,-14)
        SBtn.BackgroundTransparency=1; SBtn.Text=""; SBtn.ZIndex=4
        SBtn.MouseButton1Down:Connect(function()
            activeDrag={track=Track,mark=Mark,isRaw=true,
                cb=function(r) Mark.Position=UDim2.new(r,0,0.5,0); onDragFn(r) end}
        end)
        return Track,grad,Mark
    end
    local function updateAll()
        local color=Color3.fromHSV(curH,curS,curV)
        Preview.BackgroundColor3=color
        local r,g,b=math.floor(color.R*255),math.floor(color.G*255),math.floor(color.B*255)
        hexLbl.Text=string.format("#%02X%02X%02X  R:%d G:%d B:%d",r,g,b,r,g,b)
        if sGradRef then
            sGradRef.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHSV(curH,0,math.max(curV,0.3))),ColorSequenceKeypoint.new(1,Color3.fromHSV(curH,1,math.max(curV,0.3)))})
        end
        if vGradRef then
            vGradRef.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0,0,0)),ColorSequenceKeypoint.new(1,Color3.fromHSV(curH,math.max(curS,0.2),1))})
        end
        if onColorChanged then onColorChanged(color) end
    end
    local _,hGrad,_=makeRGBSlider(23,"H",curH,function(r) curH=r; updateAll() end)
    local kps={}
    for i=0,6 do kps[i+1]=ColorSequenceKeypoint.new(i/6,Color3.fromHSV(i/6,1,1)) end
    hGrad.Color=ColorSequence.new(kps)
    local _,sG,_=makeRGBSlider(43,"S",curS,function(r) curS=r; updateAll() end)
    sGradRef=sG
    local _,vG,_=makeRGBSlider(63,"V",curV,function(r) curV=r; updateAll() end)
    vGradRef=vG
    updateAll()
    return Card
end

local function criarToggle(pai,nome,sub,info,padrao,cbLigar,cbDesligar,ordem)
    local Card,Bar=baseCard(pai,50,ordem); local estado=padrao or false
    local Pill,_,setPill=criarPill(Card,estado)
    local TRow,_=makeTitleRow(Card,nome,56); criarInfoBtn(TRow,info)
    local SLbl=lbl(Card,sub or "",10,nil,HC.TextMuted,1)
    SLbl.Size=UDim2.new(1,-64,0,14); SLbl.Position=UDim2.new(0,12,0,30); SLbl.TextXAlignment=Enum.TextXAlignment.Left
    Bar.BackgroundTransparency=estado and 0 or 1
    if estado and cbLigar then cbLigar() end
    local function setVisual(e) estado=e; setPill(e); Bar.BackgroundTransparency=e and 0 or 1 end
    table.insert(allToggleSetters,{fn=function() setVisual(false) end})
    local Btn=Instance.new("TextButton",Card); Btn.Size=UDim2.new(1,0,1,0); Btn.BackgroundTransparency=1; Btn.Text=""; Btn.ZIndex=1
    Btn.MouseButton1Click:Connect(function()
        pT(); estado=not estado; setPill(estado); tw(Bar,{BackgroundTransparency=estado and 0 or 1},0.15):Play()
        if estado then if cbLigar then cbLigar() end else if cbDesligar then cbDesligar() end end
    end)
    table.insert(allCards,{card=Card,tab=currentTab,name=string.lower(nome),keywords=string.lower(sub or ""),origParent=pai})
    return Card,function(e) setVisual(e); if e then if cbLigar then cbLigar() end else if cbDesligar then cbDesligar() end end end
end

local function criarToggleKB(pai,nome,sub,info,kbId,padrao,cbArmar,cbDesarmar,ordem)
    local Card,Bar=baseCard(pai,52,ordem); local estado=padrao or false
    local Pill,_,setPill=criarPill(Card,estado)
    criarKBBtn(Card,kbId,-56)
    local TRow,_=makeTitleRow(Card,nome,148); criarInfoBtn(TRow,info)
    local SLbl=lbl(Card,sub or "",10,nil,HC.TextMuted,1)
    SLbl.Size=UDim2.new(1,-156,0,14); SLbl.Position=UDim2.new(0,12,0,32); SLbl.TextXAlignment=Enum.TextXAlignment.Left
    Bar.BackgroundTransparency=estado and 0 or 1
    if estado and cbArmar then cbArmar() end
    local function setVisual(e) estado=e; setPill(e); Bar.BackgroundTransparency=e and 0 or 1 end
    table.insert(allToggleSetters,{fn=function() setVisual(false); if cbDesarmar then cbDesarmar() end end})
    local Btn=Instance.new("TextButton",Card); Btn.Size=UDim2.new(1,0,1,0); Btn.BackgroundTransparency=1; Btn.Text=""; Btn.ZIndex=1
    Btn.MouseButton1Click:Connect(function()
        pT(); estado=not estado; setPill(estado); tw(Bar,{BackgroundTransparency=estado and 0 or 1},0.15):Play()
        if estado then if cbArmar then cbArmar() end else if cbDesarmar then cbDesarmar() end end
    end)
    table.insert(allCards,{card=Card,tab=currentTab,name=string.lower(nome),keywords=string.lower(sub or ""),origParent=pai})
    return Card,function(e) setVisual(e); if e then if cbArmar then cbArmar() end else if cbDesarmar then cbDesarmar() end end end
end

local function criarSoKB(pai,nome,sub,info,kbId,ordem)
    local Card,_=baseCard(pai,50,ordem); criarKBBtn(Card,kbId,-8)
    local TRow,_=makeTitleRow(Card,nome,98); criarInfoBtn(TRow,info)
    local SLbl=lbl(Card,sub or "",10,nil,HC.TextMuted,1)
    SLbl.Size=UDim2.new(1,-106,0,14); SLbl.Position=UDim2.new(0,12,0,30); SLbl.TextXAlignment=Enum.TextXAlignment.Left
    table.insert(allCards,{card=Card,tab=currentTab,name=string.lower(nome),keywords=string.lower(sub or ""),origParent=pai})
    return Card
end

local function criarSlider(pai,nome,sub,info,minV,maxV,padrao,cb,ordem)
    local Card,_=baseCard(pai,72,ordem)
    local ratio0=(padrao-minV)/math.max(maxV-minV,1)
    local ValLbl=lbl(Card,tostring(padrao),13,Enum.Font.GothamBold,HC.Accent,1)
    ValLbl.Size=UDim2.new(0,52,0,18); ValLbl.AnchorPoint=Vector2.new(1,0); ValLbl.Position=UDim2.new(1,-8,0,7); ValLbl.TextXAlignment=Enum.TextXAlignment.Right
    local TRow,_=makeTitleRow(Card,nome,62); criarInfoBtn(TRow,info)
    local SLbl=lbl(Card,sub or "",10,nil,HC.TextMuted,1)
    SLbl.Size=UDim2.new(1,-70,0,12); SLbl.Position=UDim2.new(0,12,0,28); SLbl.TextXAlignment=Enum.TextXAlignment.Left
    local Track=Instance.new("Frame",Card); Track.Size=UDim2.new(1,-24,0,6); Track.Position=UDim2.new(0,12,0,54)
    Track.BackgroundColor3=HC.Border; Track.BorderSizePixel=0; corner(Track,99)
    local Fill=Instance.new("Frame",Track); Fill.Size=UDim2.new(ratio0,0,1,0); Fill.BackgroundColor3=HC.Accent; Fill.BorderSizePixel=0; corner(Fill,99)
    local Mark=Instance.new("Frame",Track); Mark.Size=UDim2.new(0,14,0,14); Mark.AnchorPoint=Vector2.new(0.5,0.5)
    Mark.Position=UDim2.new(ratio0,0,0.5,0); Mark.BackgroundColor3=Color3.new(1,1,1); Mark.BorderSizePixel=0; Mark.ZIndex=2; corner(Mark,99)
    local SBtn=Instance.new("TextButton",Track); SBtn.Size=UDim2.new(1,0,0,26); SBtn.Position=UDim2.new(0,0,0.5,-13)
    SBtn.BackgroundTransparency=1; SBtn.Text=""; SBtn.ZIndex=3
    SBtn.MouseButton1Down:Connect(function() pC(); activeDrag={track=Track,fill=Fill,mark=Mark,valLbl=ValLbl,minV=minV,maxV=maxV,cb=cb} end)
    table.insert(allCards,{card=Card,tab=currentTab,name=string.lower(nome),keywords=string.lower(sub or ""),origParent=pai})
    return Card
end

local function criarBotao(pai,nome,sub,info,acao,ordem)
    local Card,_=baseCard(pai,50,ordem)
    local TRow,_=makeTitleRow(Card,nome,88); criarInfoBtn(TRow,info)
    local SLbl=lbl(Card,sub or "",10,nil,HC.TextMuted,1)
    SLbl.Size=UDim2.new(1,-96,0,14); SLbl.Position=UDim2.new(0,12,0,30); SLbl.TextXAlignment=Enum.TextXAlignment.Left
    local BtnEx=Instance.new("TextButton",Card); BtnEx.Size=UDim2.new(0,76,0,28)
    BtnEx.AnchorPoint=Vector2.new(1,0.5); BtnEx.Position=UDim2.new(1,-8,0.5,0)
    BtnEx.BackgroundColor3=HC.Accent; BtnEx.BorderSizePixel=0; BtnEx.Text="Executar"
    BtnEx.TextColor3=Color3.new(1,1,1); BtnEx.TextSize=11; BtnEx.Font=Enum.Font.GothamBold; BtnEx.ZIndex=5; corner(BtnEx,6)
    BtnEx.MouseButton1Click:Connect(function()
        pC(); tw(BtnEx,{BackgroundColor3=HC.AccentDark},0.1):Play()
        task.delay(0.15,function() tw(BtnEx,{BackgroundColor3=HC.Accent},0.1):Play() end)
        if acao then acao() end
    end)
    table.insert(allCards,{card=Card,tab=currentTab,name=string.lower(nome),keywords=string.lower(sub or ""),origParent=pai})
    return Card,BtnEx
end

local function criarSubToggle(pai,nome,info,padrao,cb,ordem)
    local Card=Instance.new("Frame",pai); Card.Size=UDim2.new(1,-8,0,38)
    Card.BackgroundColor3=Color3.fromRGB(26,26,40); Card.BorderSizePixel=0; Card.LayoutOrder=ordem; corner(Card,6)
    local estado=padrao or false
    local Pill,_,setPill=criarPill(Card,estado); Pill.Size=UDim2.new(0,36,0,18); Pill.Position=UDim2.new(1,-8,0.5,0)
    local TRow,NLbl=makeTitleRow(Card,nome,50,0)
    TRow.Position=UDim2.new(0,10,0.5,-9); TRow.Size=UDim2.new(1,-60,0,18)
    NLbl.TextSize=11; NLbl.Font=Enum.Font.GothamSemibold; NLbl.TextColor3=estado and HC.Text or HC.TextMuted
    if info and info~="" then criarInfoBtn(TRow,info) end
    if estado and cb then cb(true) end
    local Btn=Instance.new("TextButton",Card); Btn.Size=UDim2.new(1,0,1,0); Btn.BackgroundTransparency=1; Btn.Text=""; Btn.ZIndex=1
    Btn.MouseButton1Click:Connect(function()
        pC(); estado=not estado; setPill(estado); NLbl.TextColor3=estado and HC.Text or HC.TextMuted
        if cb then cb(estado) end
    end)
    return Card,function(e) estado=e; setPill(e); NLbl.TextColor3=e and HC.Text or HC.TextMuted; if cb then cb(e) end end
end

local function criarItemBloqueado(pai,nome,ordem)
    local F=Instance.new("Frame",pai); F.Size=UDim2.new(1,0,0,46)
    F.BackgroundColor3=Color3.fromRGB(24,22,34); F.BorderSizePixel=0; F.LayoutOrder=ordem; corner(F,8)
    stroke(F,Color3.fromRGB(120,92,42),0.45)
    local stripe=Instance.new("Frame",F)
    stripe.Size=UDim2.new(0,3,0.62,0); stripe.Position=UDim2.new(0,0,0.19,0)
    stripe.BackgroundColor3=Color3.fromRGB(240,176,56); stripe.BorderSizePixel=0; corner(stripe,99)
    local nl=lbl(F,nome,12,Enum.Font.GothamSemibold,HC.TextMuted,1)
    nl.Size=UDim2.new(1,-112,0,18); nl.Position=UDim2.new(0,14,0,8); nl.TextXAlignment=Enum.TextXAlignment.Left
    local desc=lbl(F,"Funcao ainda nao configurada",9,Enum.Font.Gotham,Color3.fromRGB(132,126,148),1)
    desc.Size=UDim2.new(1,-112,0,14); desc.Position=UDim2.new(0,14,0,26); desc.TextXAlignment=Enum.TextXAlignment.Left
    local badge=Instance.new("Frame",F); badge.Size=UDim2.new(0,88,0,24); badge.AnchorPoint=Vector2.new(1,0.5)
    badge.Position=UDim2.new(1,-8,0.5,0); badge.BackgroundColor3=Color3.fromRGB(48,38,22); badge.BorderSizePixel=0; corner(badge,6)
    stroke(badge,Color3.fromRGB(240,176,56),0.5)
    local bl=lbl(badge,"Planejado",9,Enum.Font.GothamBold,Color3.fromRGB(240,176,56),1)
    bl.Size=UDim2.new(1,0,1,0); bl.TextXAlignment=Enum.TextXAlignment.Center
    return F
end

BZBuildBossFarmSection=function(page,baseOrder)
    local base=baseOrder or 1
    local state={
        running=false,target=nil,conn=nil,
        distance=10,height=2,selectedBossName=nil,
        bossOptions={"Ember","Boss","Mission Boss","NPC Boss","Tailed Beast","Kor","Su","Mao","Isu","Sun","Ku","Sei","Chu","Gai"},
        skillOrder={"R","T","Y","F","G","H","Q","V","B","N"},
        skillKeys={},skillInterval=0.8,lastSkill=0,skillIndex=1,lastSkillLog=0,
        prevCameraType=nil,prevCameraSubject=nil
    }
    local selectedLabel=nil; local modeTitle=nil; local modeSub=nil; local modeBtn=nil; local bossListFrame=nil; local bossPickerOpen=false
    local skillButtons={}; local skillSummary=nil
    local function bossRoot(model)
        if not model or not model:IsA("Model") then return nil end
        return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("Head",true) or model:FindFirstChildWhichIsA("BasePart",true)
    end
    local function bossAlive(model)
        if not model or not model:IsA("Model") or not model.Parent then return false end
        local hum=model:FindFirstChildOfClass("Humanoid")
        return hum and hum.Health>0 and bossRoot(model)~=nil
    end
    local function isBossModel(model)
        if not model or not model:IsA("Model") or model==LocalPlayer.Character then return false end
        if Players:GetPlayerFromCharacter(model) or not model:FindFirstChildOfClass("Humanoid") then return false end
        if model:GetAttribute("IsBoss")==true or model:GetAttribute("Boss")==true or model:GetAttribute("NPC")==true then return true end
        local n=string.lower(model.Name)
        if n:find("boss",1,true) or n:find("npc",1,true) or n:find("bot",1,true) then return true end
        local p=model.Parent
        while p and p~=workspace do
            local pn=string.lower(p.Name)
            if pn:find("boss",1,true) or pn:find("npc",1,true) or pn:find("enemy",1,true) or pn:find("mobs",1,true) then return true end
            p=p.Parent
        end
        return false
    end
    local function bossLabel(model)
        if not model then return "nenhum" end
        local hum=model:FindFirstChildOfClass("Humanoid")
        if hum then return model.Name.."  HP "..math.floor(hum.Health).."/"..math.floor(hum.MaxHealth) end
        return model.Name
    end
    local function getBosses()
        local seen={}; local list={}
        for _,obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Humanoid") then
                local model=obj.Parent
                if model and model:IsA("Model") and not seen[model] and isBossModel(model) and bossAlive(model) then
                    seen[model]=true; table.insert(list,model)
                end
            end
        end
        table.sort(list,function(a,b) return a.Name<b.Name end)
        return list
    end
    local function findBossByName(name)
        if not name or name=="" then return nil end
        local wanted=string.lower(name)
        local best=nil
        for _,model in ipairs(getBosses()) do
            local n=string.lower(model.Name)
            if n==wanted then return model end
            if not best and n:find(wanted,1,true) then best=model end
        end
        return best
    end
    local function updateModeVisual()
        if selectedLabel then
            selectedLabel.Text=state.target and ("Alvo: "..bossLabel(state.target)) or ("Selecionado: "..(state.selectedBossName or "nenhum"))
        end
        if modeTitle then modeTitle.Text=state.running and "Parar Auto Farm" or "Iniciar Auto Farm" end
        if modeSub then
            modeSub.Text=state.running and "Mantendo atras do boss e mirando nele" or "Seleciona um boss e executa o loop simples"
        end
        if modeBtn then
            modeBtn.Text=state.running and "Parar" or "Executar"
            modeBtn.BackgroundColor3=state.running and HC.Danger or HC.Accent
        end
    end
    local function getSelectedSkills()
        local list={}
        for _,key in ipairs(state.skillOrder) do
            if state.skillKeys[key] then table.insert(list,key) end
        end
        return list
    end
    local function updateSkillVisual()
        local list=getSelectedSkills()
        if skillSummary then
            skillSummary.Text=#list>0 and ("Selecionadas: "..table.concat(list,", ")) or "Nenhuma tecla selecionada"
        end
        for key,btn in pairs(skillButtons) do
            local on=state.skillKeys[key]==true
            btn.BackgroundColor3=on and HC.Accent or HC.Surface
            btn.TextColor3=on and Color3.new(1,1,1) or HC.TextMuted
        end
    end
    local function nextSkillKey()
        for _=1,#state.skillOrder do
            local key=state.skillOrder[state.skillIndex]
            state.skillIndex=(state.skillIndex % #state.skillOrder)+1
            if state.skillKeys[key] then return key end
        end
        return nil
    end
    local function useNextSkill()
        local key=nextSkillKey()
        if not key then return end
        local skillCb=typeof(_G.ZyferBossFarmUseSkill)=="function" and _G.ZyferBossFarmUseSkill or _G.ZyferBossDebugUseSkill
        if typeof(skillCb)=="function" then
            local ok,err=pcall(function() skillCb(key,state.target) end)
            if not ok and os.clock()-state.lastSkillLog>1.5 then
                state.lastSkillLog=os.clock()
                print("[Zyfer AutoBoss] Erro na skill "..key..": "..tostring(err))
            end
        elseif os.clock()-state.lastSkillLog>2 then
            state.lastSkillLog=os.clock()
            print("[Zyfer AutoBoss] Skill callback nao configurada:",key,state.target and state.target.Name or "nil")
        end
    end
    local function setTarget(model)
        if bossAlive(model) then
            state.target=model
            updateModeVisual()
            showTopNotif("Boss selecionado: "..model.Name,HC.Info)
        else
            state.target=nil
            updateModeVisual()
            showTopNotif("Boss invalido ou morto",HC.Danger)
        end
    end
    local function restoreCamera()
        if not state.prevCameraType then return end
        pcall(function()
            Camera.CameraType=state.prevCameraType or Enum.CameraType.Custom
            if state.prevCameraSubject then Camera.CameraSubject=state.prevCameraSubject end
            local hum=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if Camera.CameraType==Enum.CameraType.Custom and hum then Camera.CameraSubject=hum end
        end)
        state.prevCameraType=nil; state.prevCameraSubject=nil
    end
    local function stopLoop(msg)
        state.running=false
        if state.conn then state.conn:Disconnect(); state.conn=nil end
        if _G.ZyferBossFarmAimTarget==state.target then _G.ZyferBossFarmAimTarget=nil end
        restoreCamera()
        updateModeVisual()
        if msg then showTopNotif(msg,HC.Border) end
    end
    local function stepLoop()
        if not bossAlive(state.target) then
            local nextBoss=findBossByName(state.selectedBossName)
            if nextBoss then setTarget(nextBoss) else stopLoop("Boss Farm parado - alvo sumiu"); return end
        end
        local char=LocalPlayer.Character; local myRoot=char and char:FindFirstChild("HumanoidRootPart")
        local root=bossRoot(state.target)
        if not char or not myRoot or not root then return end
        local aimPos=root.Position+Vector3.new(0,2,0)
        local behindPos=root.Position-root.CFrame.LookVector*state.distance+Vector3.new(0,state.height,0)
        myRoot.AssemblyLinearVelocity=Vector3.zero
        myRoot.AssemblyAngularVelocity=Vector3.zero
        myRoot.CFrame=CFrame.lookAt(behindPos,aimPos)
        _G.ZyferBossFarmAimTarget=state.target
        if os.clock()-state.lastSkill>=state.skillInterval then
            state.lastSkill=os.clock()
            useNextSkill()
        end
    end
    local function startLoop()
        if not bossAlive(state.target) then
            if not state.selectedBossName then showTopNotif("Escolha um boss primeiro",HC.Danger); return end
            local found=findBossByName(state.selectedBossName)
            if found then setTarget(found) else showTopNotif("Boss selecionado nao encontrado",HC.Danger); return end
        end
        if state.conn then state.conn:Disconnect(); state.conn=nil end
        state.prevCameraType=Camera.CameraType
        state.prevCameraSubject=Camera.CameraSubject
        state.running=true
        state.lastSkill=0
        state.conn=bzTrack(RunService.Heartbeat:Connect(stepLoop))
        updateModeVisual()
        showTopNotif("Auto Boss iniciado",HC.Accent)
    end
    local function toggleLoop()
        if state.running then stopLoop("Auto Boss parado") else startLoop() end
    end
    local function refreshBossList()
        if not bossListFrame then return end
        for _,child in ipairs(bossListFrame:GetChildren()) do if not child:IsA("UIListLayout") then child:Destroy() end end
        bossListFrame.Visible=bossPickerOpen
        if not bossPickerOpen then return end
        for i,bossName in ipairs(state.bossOptions) do
            local card=Instance.new("Frame",bossListFrame); card.Size=UDim2.new(1,0,0,48)
            card.BackgroundColor3=HC.Surface2; card.BorderSizePixel=0; card.LayoutOrder=i; corner(card,8); stroke(card,HC.Border,0.55)
            local nameLbl=lbl(card,bossName,12,Enum.Font.GothamBold,HC.Text,1)
            nameLbl.Size=UDim2.new(1,-112,0,18); nameLbl.Position=UDim2.new(0,12,0,8); nameLbl.TextXAlignment=Enum.TextXAlignment.Left
            local descLbl=lbl(card,"Seleciona este nome para o Boss Farm",10,nil,HC.TextMuted,1)
            descLbl.Size=UDim2.new(1,-112,0,14); descLbl.Position=UDim2.new(0,12,0,27); descLbl.TextXAlignment=Enum.TextXAlignment.Left
            local btn=Instance.new("TextButton",card); btn.Size=UDim2.new(0,88,0,28); btn.AnchorPoint=Vector2.new(1,0.5)
            btn.Position=UDim2.new(1,-8,0.5,0); btn.BackgroundColor3=HC.Accent; btn.BorderSizePixel=0
            btn.TextColor3=Color3.new(1,1,1); btn.TextSize=10; btn.Font=Enum.Font.GothamBold; btn.ZIndex=5; corner(btn,6)
            btn.Text=state.selectedBossName==bossName and "Atual" or "Selecionar"
            btn.MouseButton1Click:Connect(function()
                pC()
                state.selectedBossName=bossName
                state.target=findBossByName(bossName)
                bossPickerOpen=false
                refreshBossList()
                updateModeVisual()
                showTopNotif("Boss escolhido: "..bossName,HC.Info)
            end)
        end
    end
    table.insert(allToggleSetters,{fn=function() stopLoop() end})
    criarHeader(page,"[ BOSS FARM ]",base)
    local statusCard=Instance.new("Frame",page); statusCard.Size=UDim2.new(1,0,0,64); statusCard.LayoutOrder=base+1
    statusCard.BackgroundColor3=HC.Surface2; statusCard.BorderSizePixel=0; corner(statusCard,8); stroke(statusCard,HC.Info,0.45)
    selectedLabel=lbl(statusCard,"Alvo: nenhum",13,Enum.Font.GothamBold,HC.Text,1)
    selectedLabel.Size=UDim2.new(1,-24,0,22); selectedLabel.Position=UDim2.new(0,12,0,10); selectedLabel.TextXAlignment=Enum.TextXAlignment.Left
    local hint=lbl(statusCard,"Loop simples: fica atras do boss e usa a mira no alvo.",10,nil,HC.TextMuted,1)
    hint.Size=UDim2.new(1,-24,0,18); hint.Position=UDim2.new(0,12,0,35); hint.TextXAlignment=Enum.TextXAlignment.Left
    criarBotao(page,"Escolher Boss","Abre a lista simples de bosses configurados","Selecione um boss pelo nome antes de iniciar.",function()
        bossPickerOpen=not bossPickerOpen
        refreshBossList()
    end,base+2)
    do
        local card=Instance.new("Frame",page); card.Size=UDim2.new(1,0,0,58); card.LayoutOrder=base+3
        card.BackgroundColor3=HC.Surface2; card.BorderSizePixel=0; corner(card,8); stroke(card,HC.Accent,0.5)
        modeTitle=lbl(card,"Iniciar Auto Farm",13,Enum.Font.GothamBold,HC.Text,1)
        modeTitle.Size=UDim2.new(1,-116,0,20); modeTitle.Position=UDim2.new(0,12,0,9); modeTitle.TextXAlignment=Enum.TextXAlignment.Left
        modeSub=lbl(card,"Seleciona um boss e executa o loop simples",10,nil,HC.TextMuted,1)
        modeSub.Size=UDim2.new(1,-116,0,16); modeSub.Position=UDim2.new(0,12,0,32); modeSub.TextXAlignment=Enum.TextXAlignment.Left
        modeBtn=Instance.new("TextButton",card); modeBtn.Size=UDim2.new(0,88,0,30); modeBtn.AnchorPoint=Vector2.new(1,0.5)
        modeBtn.Position=UDim2.new(1,-10,0.5,0); modeBtn.BackgroundColor3=HC.Accent; modeBtn.BorderSizePixel=0
        modeBtn.Text="Executar"; modeBtn.TextColor3=Color3.new(1,1,1); modeBtn.TextSize=11; modeBtn.Font=Enum.Font.GothamBold; modeBtn.ZIndex=5
        corner(modeBtn,6)
        modeBtn.MouseButton1Click:Connect(function() pC(); toggleLoop() end)
    end
    criarSlider(page,"Distancia Atras","Distancia para ficar atras do boss","O personagem fica sempre atras do olhar do boss.",3,60,state.distance,function(v) state.distance=v end,base+4)
    criarSlider(page,"Altura","Altura relativa ao boss","Use 0 para ficar no chao, ou maior para ficar acima.",-2,25,state.height,function(v) state.height=v end,base+5)
    criarSlider(page,"Intervalo Skill","Tempo entre chamadas das habilidades x0.1s","8 = 0.8s. Chama _G.ZyferBossFarmUseSkill.",1,30,8,function(v) state.skillInterval=math.max(0.1,v/10) end,base+6)
    do
        local card=Instance.new("Frame",page); card.Size=UDim2.new(1,0,0,104); card.LayoutOrder=base+7
        card.BackgroundColor3=HC.Surface2; card.BorderSizePixel=0; corner(card,8); stroke(card,HC.Border,0.5)
        local title=lbl(card,"Habilidades",12,Enum.Font.GothamBold,HC.Text,1)
        title.Size=UDim2.new(1,-24,0,18); title.Position=UDim2.new(0,12,0,8); title.TextXAlignment=Enum.TextXAlignment.Left
        skillSummary=lbl(card,"Nenhuma tecla selecionada",10,nil,HC.TextMuted,1)
        skillSummary.Size=UDim2.new(1,-24,0,16); skillSummary.Position=UDim2.new(0,12,0,27); skillSummary.TextXAlignment=Enum.TextXAlignment.Left
        local grid=Instance.new("Frame",card); grid.Size=UDim2.new(1,-24,0,48); grid.Position=UDim2.new(0,12,0,50)
        grid.BackgroundTransparency=1
        local gl=Instance.new("UIGridLayout",grid)
        gl.CellSize=UDim2.new(0,42,0,22); gl.CellPadding=UDim2.new(0,6,0,6)
        gl.SortOrder=Enum.SortOrder.LayoutOrder
        for i,key in ipairs(state.skillOrder) do
            local btn=Instance.new("TextButton",grid)
            btn.Size=UDim2.new(0,42,0,22); btn.BackgroundColor3=HC.Surface; btn.BorderSizePixel=0
            btn.Text=key; btn.TextColor3=HC.TextMuted; btn.TextSize=10; btn.Font=Enum.Font.GothamBold
            btn.LayoutOrder=i; corner(btn,6); stroke(btn,HC.Border,0.55)
            skillButtons[key]=btn
            btn.MouseButton1Click:Connect(function()
                pC()
                state.skillKeys[key]=not state.skillKeys[key]
                updateSkillVisual()
            end)
        end
        updateSkillVisual()
    end
    bossListFrame=Instance.new("Frame",page); bossListFrame.Size=UDim2.new(1,0,0,0); bossListFrame.AutomaticSize=Enum.AutomaticSize.Y
    bossListFrame.BackgroundTransparency=1; bossListFrame.LayoutOrder=base+8; bossListFrame.Visible=false
    BZAddListLayout(bossListFrame,6)
    updateModeVisual()
    refreshBossList()
end

-- TAB SYSTEM
local Pages={}; local TabBtns={}; local ActiveTab=nil
local TabNames={"Visual","PVP","Skills","AutoFarm","Jogadores","TP","Misc","Creditos"}
local TabIcons={
    Visual="90267150980549",
    PVP="91510533551291",
    Skills="86436201540990",
    AutoFarm="83824642589810",
    Jogadores="87673313234521",
    TP="123444596518602",
    Misc="97179373054075",
    Creditos="70384306032834",
}
local TabIconFallback={
    Visual="O",
    PVP="+",
    Skills="*",
    AutoFarm="Y",
    Jogadores="[]",
    TP=">",
    Misc="#",
    Creditos="i",
}
HC.TabIconIdle=HC.TextMuted
HC.TabIconActive=Color3.new(1,1,1)
HC.TabIconHover=Color3.fromRGB(255,255,255)
HC.TabBgActive=HC.Accent
HC.TabBgHover=Color3.fromRGB(70,30,115)

SearchResultsPage=Instance.new("Frame",Scroll)
SearchResultsPage.Name="SearchPage"; SearchResultsPage.Size=UDim2.new(1,0,0,0)
SearchResultsPage.BackgroundTransparency=1; SearchResultsPage.Visible=false; SearchResultsPage.LayoutOrder=0; SearchResultsPage.AutomaticSize=Enum.AutomaticSize.Y
BZAddListLayout(SearchResultsPage,6)

trocarAba=function(nome)
    if ActiveTab==nome then return end
    pC(); ActiveTab=nome; TabTitle.Text=nome; SearchInput.Text=""
    SearchResultsPage.Visible=false
    BZSelectTab(nome,Pages,TabBtns,HC,tw,BZSetTabVisual,HC.TabIconActive,HC.TabIconIdle,HC.TabBgActive)
    Scroll.CanvasPosition=Vector2.new(0,0)
end

BZWireAllTabs(TabNames,TabIcons,TabIconFallback,TabList,Scroll,Pages,TabBtns,HC,corner,pad,tw,BZSetTabVisual,trocarAba,function() return ActiveTab end,HC.TabIconActive,HC.TabIconIdle,HC.TabIconHover)

HC.ThemeName="Zypher Classic"
_G.ZyferThemeName=HC.ThemeName
HC.TabIconActive=Color3.new(1,1,1)
HC.TabBgHover=Color3.fromRGB(70,30,115)
LGrad.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,HC.Accent),ColorSequenceKeypoint.new(1,HC.AccentDark)}

BZDestroyDivineUI=function()
    local ui=_G.ZyferDivineUI
    if not ui then return end
    if ui.connections then
        for _,c in ipairs(ui.connections) do pcall(function() if c.Connected then c:Disconnect() end end) end
    end
    if ui.root then pcall(function() ui.root:Destroy() end) end
    _G.ZyferDivineUI=nil
end

BZBuildDivineUI=function()
    if _G.ZyferDivineUI then return _G.ZyferDivineUI end
    local ui={connections={},pages={},tabs={},activeTabTween=nil,activeShadowTween=nil,activeTabName=nil}
    _G.ZyferDivineUI=ui
    local function addConn(c) if typeof(c)=="RBXScriptConnection" then table.insert(ui.connections,c) end; return c end
    local function Create(className,props,children)
        local obj=Instance.new(className)
        for prop,value in pairs(props or {}) do obj[prop]=value end
        for _,child in ipairs(children or {}) do child.Parent=obj end
        return obj
    end
    local function AddCorner(obj,r) local c=Instance.new("UICorner",obj); c.CornerRadius=UDim.new(0,r or 16); return c end
    local function AddStroke(obj,color,t,thick) local s=Instance.new("UIStroke",obj); s.Color=color; s.Transparency=t or 0.35; s.Thickness=thick or 1; return s end
    local Divine={
        White=Color3.fromRGB(255,255,255), SoftWhite=Color3.fromRGB(245,250,255),
        Gold=Color3.fromRGB(214,173,78), GoldSoft=Color3.fromRGB(246,219,143),
        Blue=Color3.fromRGB(36,111,226), BlueDeep=Color3.fromRGB(24,78,178),
        BlueSoft=Color3.fromRGB(175,216,255), Text=Color3.fromRGB(38,56,92),
        Muted=Color3.fromRGB(116,130,160), DividerSoft=Color3.fromRGB(214,219,228)
    }
    local SELECTED_TAB_IMAGE="rbxassetid://110952235059423"
    local WELCOME_BG_IMAGE="rbxassetid://87375895429900"
    local CARD_TITLE_ICON_IMAGE="rbxassetid://72385347857272"
    local WELCOME_TITLE_ICON_IMAGE="rbxassetid://73840035255401"
    local SIDEBAR_FOOTER_IMAGE="rbxassetid://75999345063179"
    pcall(function()
        game:GetService("ContentProvider"):PreloadAsync({SELECTED_TAB_IMAGE,WELCOME_BG_IMAGE,CARD_TITLE_ICON_IMAGE,WELCOME_TITLE_ICON_IMAGE,SIDEBAR_FOOTER_IMAGE})
    end)

    ui.root=Create("Frame",{Name="_ZypherDivineRoot",Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Visible=hubVisible,ZIndex=20,Parent=ScreenGui})
    local Shadow=Create("Frame",{Name="Shadow",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,12),Size=UDim2.new(0,802,0,502),BackgroundColor3=Color3.fromRGB(44,73,120),BackgroundTransparency=0.86,BorderSizePixel=0,ZIndex=21,Parent=ui.root})
    AddCorner(Shadow,34)
    local DMain=Create("Frame",{Name="DivineMain",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0,790,0,492),BackgroundColor3=Divine.SoftWhite,BackgroundTransparency=0.08,BorderSizePixel=0,ClipsDescendants=true,ZIndex=22,Parent=ui.root})
    ui.main=DMain
    AddCorner(DMain,31); AddStroke(DMain,Divine.GoldSoft,0.08,1.6)
    Create("UIGradient",{Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(0.52,Color3.fromRGB(232,244,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,249,235))},Rotation=25,Parent=DMain})

    local Topbar=Create("Frame",{Name="Topbar",Size=UDim2.new(1,0,0,108),BackgroundTransparency=1,ZIndex=23,Parent=DMain})
    Create("TextLabel",{Name="Title",AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,18),Size=UDim2.new(0,380,0,42),BackgroundTransparency=1,Text="Zypher",Font=Enum.Font.Garamond,TextSize=42,TextColor3=Divine.Gold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=24,Parent=Topbar})
    Create("TextLabel",{Name="Subtitle",AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,62),Size=UDim2.new(0,380,0,22),BackgroundTransparency=1,Text="DIVINE CONTROL HUB",Font=Enum.Font.GothamMedium,TextSize=10,TextColor3=Divine.Muted,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=24,Parent=Topbar})
    local WindowControls=Create("Frame",{Name="WindowControls",Position=UDim2.new(1,-100,0,20),Size=UDim2.new(0,76,0,30),BackgroundColor3=Divine.White,BackgroundTransparency=0.27,BorderSizePixel=0,ZIndex=25,Parent=Topbar})
    AddCorner(WindowControls,18)
    local Minimize=Create("TextButton",{Name="Minimize",Position=UDim2.new(0,7,0,0),Size=UDim2.new(0,28,1,0),BackgroundTransparency=1,Text="-",Font=Enum.Font.GothamBold,TextSize=18,TextColor3=Divine.Text,ZIndex=26,Parent=WindowControls})
    local Close=Create("TextButton",{Name="Close",Position=UDim2.new(0,41,0,0),Size=UDim2.new(0,28,1,0),BackgroundTransparency=1,Text="x",Font=Enum.Font.GothamBold,TextSize=16,TextColor3=Divine.Text,ZIndex=26,Parent=WindowControls})
    addConn(Minimize.MouseButton1Click:Connect(function() pC(); esconderHub() end))
    addConn(Close.MouseButton1Click:Connect(function() pC(); if destruirHubDefinitivo then destruirHubDefinitivo() end end))

    local Body=Create("Frame",{Name="Body",Position=UDim2.new(0,26,0,108),Size=UDim2.new(1,-52,1,-146),BackgroundTransparency=1,ClipsDescendants=false,ZIndex=23,Parent=DMain})
    local Footer=Create("Frame",{Name="Footer",AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-16),Size=UDim2.new(1,-72,0,24),BackgroundTransparency=1,ZIndex=24,Parent=DMain})
    Create("TextLabel",{Name="Slogan",Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="ELEVATE BEYOND LIMITS.",Font=Enum.Font.GothamMedium,TextSize=10,TextColor3=Divine.BlueDeep,TextTransparency=0.08,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=25,Parent=Footer})
    Create("TextLabel",{Name="LeftDecor",AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(0.5,-112,0.5,0),Size=UDim2.new(0,38,0,18),BackgroundTransparency=1,Text="-",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Divine.Gold,TextTransparency=0.18,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=25,Parent=Footer})
    Create("TextLabel",{Name="RightDecor",AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0.5,112,0.5,0),Size=UDim2.new(0,38,0,18),BackgroundTransparency=1,Text="-",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Divine.Gold,TextTransparency=0.18,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=25,Parent=Footer})

    local SidebarD=Create("Frame",{Name="Sidebar",Position=UDim2.new(0,-2,0,-12),Size=UDim2.new(0,150,1,36),BackgroundColor3=Divine.White,BackgroundTransparency=0.34,BorderSizePixel=0,ClipsDescendants=false,ZIndex=23,Parent=Body})
    AddCorner(SidebarD,24); AddStroke(SidebarD,Divine.White,0.34,1)
    Create("UIPadding",{PaddingTop=UDim.new(0,10),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),PaddingBottom=UDim.new(0,16),Parent=SidebarD})
    local TabArea=Create("Frame",{Name="TabArea",Position=UDim2.new(0,-5,0,-4),Size=UDim2.new(1,10,0,264),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=24,Parent=SidebarD})
    local SelectorShadow=Create("ImageLabel",{Name="ActiveTabSelectorShadow",AnchorPoint=Vector2.new(0,0),Position=UDim2.new(0,-23,0,-8),Size=UDim2.new(1,42,0,78),BackgroundTransparency=1,Image=SELECTED_TAB_IMAGE,ImageColor3=Color3.fromRGB(163,122,39),ImageTransparency=1,ScaleType=Enum.ScaleType.Stretch,Visible=false,ZIndex=26,Parent=TabArea})
    local Selector=Create("ImageLabel",{Name="ActiveTabSelector",AnchorPoint=Vector2.new(0,0),Position=UDim2.new(0,-22,0,-12),Size=UDim2.new(1,42,0,76),BackgroundTransparency=1,Image=SELECTED_TAB_IMAGE,ImageTransparency=0,ScaleType=Enum.ScaleType.Stretch,Visible=true,ZIndex=27,Parent=TabArea})
    local TabListD=Create("ScrollingFrame",{Name="TabList",Size=UDim2.new(1,-4,1,0),Position=UDim2.new(0,0,0,0),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,ScrollBarImageColor3=Divine.GoldSoft,ScrollBarImageTransparency=0.28,ScrollingDirection=Enum.ScrollingDirection.Y,VerticalScrollBarInset=Enum.ScrollBarInset.ScrollBar,ZIndex=30,Parent=TabArea})
    Create("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder,Parent=TabListD})
    local Brand=Create("Frame",{Name="SidebarFooter",AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-4),Size=UDim2.new(1,-6,0,96),BackgroundTransparency=1,ZIndex=24,Parent=SidebarD})
    Create("ImageLabel",{Name="BrandIcon",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,-2,1,-8),BackgroundTransparency=1,Image=SIDEBAR_FOOTER_IMAGE,ImageTransparency=0.03,ScaleType=Enum.ScaleType.Fit,ZIndex=25,Parent=Brand})

    local Content=Create("Frame",{Name="Content",Position=UDim2.new(0,184,0,0),Size=UDim2.new(1,-184,1,0),BackgroundTransparency=1,ClipsDescendants=false,ZIndex=23,Parent=Body})
    local function Card(parent,name,pos,size)
        local card=Create("Frame",{Name=name,Position=pos,Size=size,BackgroundColor3=Divine.White,BackgroundTransparency=0.24,BorderSizePixel=0,ClipsDescendants=true,ZIndex=24,Parent=parent})
        AddCorner(card,22); AddStroke(card,Divine.White,0.44,1)
        return card
    end
    local function CardTitle(parent,text)
        local useIcon=(text=="Main Controls" or text=="Player Info" or text=="Quick Actions")
        if useIcon then
            Create("ImageLabel",{Name="CardTitleIcon",Position=UDim2.new(0,20,0,16),Size=UDim2.new(0,18,0,18),BackgroundTransparency=1,Image=CARD_TITLE_ICON_IMAGE,ImageTransparency=0.02,ScaleType=Enum.ScaleType.Fit,ZIndex=28,Parent=parent})
        end
        Create("TextLabel",{Name="CardTitle",Position=useIcon and UDim2.new(0,44,0,14) or UDim2.new(0,20,0,14),Size=useIcon and UDim2.new(1,-64,0,24) or UDim2.new(1,-40,0,24),BackgroundTransparency=1,Text=text,Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Divine.Blue,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=28,Parent=parent})
    end
    local function Page(name)
        local page=Create("CanvasGroup",{Name=name,Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,GroupTransparency=1,Visible=false,Active=false,ZIndex=24,Parent=Content})
        ui.pages[name]=page
        return page
    end
    local function Scroll(parent)
        local sc=Create("ScrollingFrame",{Position=UDim2.new(0,14,0,46),Size=UDim2.new(1,-28,1,-60),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,ScrollBarImageColor3=Divine.GoldSoft,ScrollBarImageTransparency=0.18,VerticalScrollBarInset=Enum.ScrollBarInset.ScrollBar,ZIndex=25,Parent=parent})
        Create("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,Parent=sc})
        return sc
    end
    local function PremiumButton(parent,text,sub,blue,cb)
        local b=Create("TextButton",{Name=text,Size=UDim2.new(1,0,0,36),BackgroundColor3=blue and Divine.Blue or Divine.White,BackgroundTransparency=blue and 0.02 or 0.22,BorderSizePixel=0,AutoButtonColor=false,Text="",ZIndex=25,Parent=parent})
        AddCorner(b,16); AddStroke(b,blue and Divine.BlueSoft or Divine.GoldSoft,0.25,1)
        if blue then Create("UIGradient",{Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(57,130,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(158,208,255))},Rotation=20,Parent=b}) end
        Create("TextLabel",{Position=UDim2.new(0,16,0,4),Size=UDim2.new(1,-32,0,16),BackgroundTransparency=1,Text=text,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=blue and Divine.White or Divine.Text,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=26,Parent=b})
        Create("TextLabel",{Position=UDim2.new(0,16,0,20),Size=UDim2.new(1,-32,0,14),BackgroundTransparency=1,Text=sub or "",Font=Enum.Font.Gotham,TextSize=9,TextColor3=blue and Color3.fromRGB(235,247,255) or Divine.Muted,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=26,Parent=b})
        addConn(b.MouseButton1Click:Connect(function() pC(); if cb then cb() end end))
        return b
    end
    local function DivineToggle(parent,title,desc,on,cb)
        local state=on and true or false
        local row=Create("Frame",{Name=title,Size=UDim2.new(1,0,0,54),BackgroundColor3=Divine.White,BackgroundTransparency=0.5,BorderSizePixel=0,ZIndex=25,Parent=parent})
        AddCorner(row,16)
        Create("TextLabel",{Position=UDim2.new(0,14,0,8),Size=UDim2.new(1,-92,0,20),BackgroundTransparency=1,Text=title,Font=Enum.Font.GothamSemibold,TextSize=12,TextColor3=Divine.Text,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=26,Parent=row})
        Create("TextLabel",{Position=UDim2.new(0,14,0,28),Size=UDim2.new(1,-92,0,18),BackgroundTransparency=1,Text=desc,Font=Enum.Font.Gotham,TextSize=10,TextColor3=Divine.Muted,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=26,Parent=row})
        local tb=Create("TextButton",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-14,0.5,0),Size=UDim2.new(0,48,0,25),BackgroundColor3=state and Divine.Blue or Color3.fromRGB(210,218,230),BorderSizePixel=0,Text="",ZIndex=26,Parent=row})
        AddCorner(tb,99)
        local knob=Create("Frame",{Position=state and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9),Size=UDim2.new(0,18,0,18),BackgroundColor3=Divine.White,BorderSizePixel=0,ZIndex=27,Parent=tb})
        AddCorner(knob,99)
        addConn(tb.MouseButton1Click:Connect(function()
            state=not state
            tw(tb,{BackgroundColor3=state and Divine.Blue or Color3.fromRGB(210,218,230)},0.18):Play()
            tw(knob,{Position=state and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)},0.18):Play()
            if cb then cb(state) end
        end))
        return row
    end
    local function SetPage(name)
        if not ui.pages[name] then return end
        ui.activeTabName=name
        for pn,page in pairs(ui.pages) do
            if pn==name then
                page.Visible=true; page.Active=true; page.Position=UDim2.new(0,10,0,0)
                tw(page,{Position=UDim2.new(0,0,0,0),GroupTransparency=0},0.22,Enum.EasingStyle.Sine):Play()
            else
                page.Active=false
                if page.Visible then tw(page,{Position=UDim2.new(0,-8,0,0),GroupTransparency=1},0.16,Enum.EasingStyle.Sine):Play() end
                task.delay(0.17,function()
                    if ui.activeTabName~=pn and page.Parent then
                        page.Visible=false; page.Position=UDim2.new(0,0,0,0); page.GroupTransparency=1
                    end
                end)
            end
        end
        local tab=ui.tabs[name]
        if tab then
            local y=tab.Button.AbsolutePosition.Y-TabArea.AbsolutePosition.Y-16
            if y~=y or math.abs(y)>1000 then y=(tab.order-1)*50 end
            local shadowY=tab.Button.AbsolutePosition.Y-TabArea.AbsolutePosition.Y-12
            if shadowY~=shadowY or math.abs(shadowY)>1000 then shadowY=(tab.order-1)*50 end
            local h=(tab.Button.AbsoluteSize.Y>0 and tab.Button.AbsoluteSize.Y or 48)+28
            if ui.activeTabTween then ui.activeTabTween:Cancel(); ui.activeTabTween=nil end
            if ui.activeShadowTween then ui.activeShadowTween:Cancel(); ui.activeShadowTween=nil end
            Selector.Visible=true; SelectorShadow.Visible=false
            ui.activeTabTween=tw(Selector,{Position=UDim2.new(0,-22,0,y),Size=UDim2.new(1,42,0,h)},0.3,Enum.EasingStyle.Quint)
            ui.activeShadowTween=tw(SelectorShadow,{Position=UDim2.new(0,-23,0,shadowY-4),Size=UDim2.new(1,42,0,h+10)},0.3,Enum.EasingStyle.Quint)
        end
        for tn,data in pairs(ui.tabs) do data.Label.TextColor3=(tn==name) and Divine.Blue or Divine.Text end
    end
    local function MakeTab(name,order)
        local b=Create("TextButton",{Name=name.."_Tab",LayoutOrder=order,Size=UDim2.new(1,0,0,48),BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false,Text="",ClipsDescendants=false,ZIndex=30,Parent=TabListD})
        Create("Frame",{Name="IconSlot",Position=UDim2.new(0,14,0.5,-9),Size=UDim2.new(0,18,0,18),BackgroundTransparency=1,ZIndex=34,Parent=b})
        local label=Create("TextLabel",{Name="Label",Position=UDim2.new(0,44,0,0),Size=UDim2.new(1,-52,1,0),BackgroundTransparency=1,Text=name,Font=Enum.Font.GothamSemibold,TextSize=12,TextColor3=Divine.Text,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=36,Parent=b})
        if order<5 then Create("Frame",{Name="TabDivider",AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,2),Size=UDim2.new(1,-32,0,1),BackgroundColor3=Divine.DividerSoft,BackgroundTransparency=0.76,BorderSizePixel=0,ZIndex=32,Parent=b}) end
        addConn(b.MouseEnter:Connect(function() if ui.activeTabName~=name then tw(label,{TextColor3=Divine.Blue},0.15,Enum.EasingStyle.Sine):Play() end end))
        addConn(b.MouseLeave:Connect(function() if ui.activeTabName~=name then tw(label,{TextColor3=Divine.Text},0.15,Enum.EasingStyle.Sine):Play() end end))
        addConn(b.MouseButton1Click:Connect(function() SetPage(name) end))
        ui.tabs[name]={Button=b,Label=label,order=order}
    end

    local Home=Page("Home"); Home.Visible=true; Home.Active=true; Home.GroupTransparency=0
    local Welcome=Card(Home,"Welcome",UDim2.new(0,0,0,0),UDim2.new(1,0,0,94))
    Create("ImageLabel",{Name="WelcomeBackgroundImage",Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Image=WELCOME_BG_IMAGE,ImageTransparency=0.05,ScaleType=Enum.ScaleType.Crop,ZIndex=24,Parent=Welcome}); AddCorner(Welcome:FindFirstChild("WelcomeBackgroundImage"),22)
    Create("Frame",{Name="WelcomeOverlay",Size=UDim2.new(1,0,1,0),BackgroundColor3=Divine.White,BackgroundTransparency=0.54,BorderSizePixel=0,ZIndex=25,Parent=Welcome}); AddCorner(Welcome:FindFirstChild("WelcomeOverlay"),22)
    Create("ImageLabel",{Name="WelcomeHeroImage",Position=UDim2.new(0,18,0,10),Size=UDim2.new(0,82,1,-20),BackgroundTransparency=1,Image=WELCOME_TITLE_ICON_IMAGE,ImageTransparency=0.02,ScaleType=Enum.ScaleType.Fit,ZIndex=26,Parent=Welcome})
    Create("TextLabel",{Position=UDim2.new(0,116,0,18),Size=UDim2.new(1,-140,0,26),BackgroundTransparency=1,Text="Welcome to Zypher",Font=Enum.Font.GothamBold,TextSize=18,TextColor3=Divine.Blue,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=26,Parent=Welcome})
    Create("TextLabel",{Position=UDim2.new(0,116,0,47),Size=UDim2.new(1,-140,0,32),BackgroundTransparency=1,Text="Visual Divine completo usando a mesma logica funcional do hub.",Font=Enum.Font.Gotham,TextSize=12,TextColor3=Divine.Muted,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,ZIndex=26,Parent=Welcome})
    local HomeControls=Card(Home,"Controls",UDim2.new(0,0,0,112),UDim2.new(0.52,-10,1,-112)); CardTitle(HomeControls,"Main Controls")
    local HScroll=Scroll(HomeControls)
    PremiumButton(HScroll,"Abrir Classic","Voltar para o hub visual Classic.",false,function() applyTheme("Zypher Classic") end)
    DivineToggle(HScroll,"Highlight","Contorno visual dos players.",espHighlight,function(on) espHighlight=on; updateEspHL(); showTopNotif("Highlight "..(on and "ON" or "OFF"),on and HC.Accent or HC.Border) end)
    DivineToggle(HScroll,"ESP","Nomes e informacoes dos jogadores.",espAtivo,function(on) espAtivo=on; showTopNotif("ESP "..(on and "ON" or "OFF"),on and HC.Accent or HC.Border) end)
    local Info=Card(Home,"Info",UDim2.new(0.52,10,0,112),UDim2.new(0.48,-10,0,86)); CardTitle(Info,"Player Info")
    Create("TextLabel",{Position=UDim2.new(0,20,0,45),Size=UDim2.new(1,-40,0,22),BackgroundTransparency=1,Text="Username: "..LocalPlayer.Name,Font=Enum.Font.GothamSemibold,TextSize=12,TextColor3=Divine.Text,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=25,Parent=Info})
    Create("TextLabel",{Position=UDim2.new(0,20,0,66),Size=UDim2.new(1,-40,0,20),BackgroundTransparency=1,Text="Status: Premium Visual",Font=Enum.Font.Gotham,TextSize=11,TextColor3=Divine.Gold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=25,Parent=Info})
    local Actions=Card(Home,"Actions",UDim2.new(0.52,10,0,210),UDim2.new(0.48,-10,1,-210)); CardTitle(Actions,"Quick Actions")
    local AList=Create("Frame",{Position=UDim2.new(0,18,0,50),Size=UDim2.new(1,-36,1,-66),BackgroundTransparency=1,ZIndex=25,Parent=Actions})
    Create("UIListLayout",{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder,Parent=AList})
    PremiumButton(AList,"Tecla 5","Menu rapido ao mirar em player.",true,function() BZTryQuickMenu(LocalPlayer,Players,Camera,ScreenGui,showTopNotif) end)
    PremiumButton(AList,"Minimizar","Fecha somente a interface.",false,function() esconderHub() end)

    local function SimplePage(name,title,desc,fillFn)
        local P=Page(name)
        local Header=Card(P,name.."_Header",UDim2.new(0,0,0,0),UDim2.new(1,0,0,116))
        Create("TextLabel",{Position=UDim2.new(0,24,0,23),Size=UDim2.new(1,-48,0,30),BackgroundTransparency=1,Text=title,Font=Enum.Font.GothamBold,TextSize=22,TextColor3=Divine.Blue,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=25,Parent=Header})
        Create("TextLabel",{Position=UDim2.new(0,24,0,58),Size=UDim2.new(1,-48,0,42),BackgroundTransparency=1,Text=desc,Font=Enum.Font.Gotham,TextSize=13,TextColor3=Divine.Muted,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,ZIndex=25,Parent=Header})
        local C=Card(P,name.."_Card",UDim2.new(0,0,0,134),UDim2.new(1,0,1,-134)); CardTitle(C,"Opcoes")
        local S=Scroll(C)
        if fillFn then fillFn(S) end
    end
    SimplePage("Combat","Combat","Recursos de combate e movimento conectados as mesmas funcoes centrais.",function(S)
        DivineToggle(S,"Aim Assist","Segure RMB para travar no alvo.",aimAtivo,function(on) aimAtivo=on; if not on then aimLockedTarget=nil; aimLastPos=nil end end)
        DivineToggle(S,"Aim NPC/Boss","Inclui NPCs, bots e bosses no Aim Assist.",aimNPCAtivo,function(on)
            aimNPCAtivo=on
            if not on and aimLockedTarget and aimLockedTarget:IsA("Model") then aimLockedTarget=nil; aimLastPos=nil end
        end)
        PremiumButton(S,"Passo Fantasma","Ativa/desativa o modo de passo.",false,function() tlModoAtivo=not tlModoAtivo; tlSetMode(tlModoAtivo); showTopNotif("Passo Fantasma "..(tlModoAtivo and "ON" or "OFF"),tlModoAtivo and HC.Accent or HC.Border) end)
        DivineToggle(S,"Voar","Liga/desliga voo direto.",flyAtivo,function(on) flyAtivo=on; if on then startFly() else stopFly() end end)
        DivineToggle(S,"Noclip","Atravessa partes solidas.",noclipAtivo,function(on) if on~=noclipAtivo then toggleNoclip() end end)
    end)
    SimplePage("Visuals","Visuals","Configuracoes visuais, ESP, highlight e visao sensorial.",function(S)
        DivineToggle(S,"ESP","Ativa ou desativa informacoes visuais.",espAtivo,function(on) espAtivo=on end)
        DivineToggle(S,"Highlight","Silhueta dos jogadores.",espHighlight,function(on) espHighlight=on; updateEspHL() end)
        DivineToggle(S,"Contorno","Liga/desliga apenas a silhueta.",espHLOutline,function(on) espHLOutline=on; updateHLColor() end)
        DivineToggle(S,"Preenchimento","Liga/desliga a cor interna.",espHLFill,function(on) espHLFill=on; updateHLColor() end)
        PremiumButton(S,"Visao Sensorial","Destaca inimigos por alguns segundos.",false,function() task.spawn(ativarVisao) end)
    end)
    SimplePage("Player","Player","Acoes do jogador, teleportes e lista de players.",function(S)
        DivineToggle(S,"Camera Livre","Camera livre com bloqueio de personagem.",freecamAtivo,function(on) if on~=freecamAtivo then toggleFreecam() end end)
        DivineToggle(S,"Invisivel","Usa a logica atual de invisibilidade.",invisAtivo,function(on) if on~=invisAtivo then toggleInvis() end end)
        DivineToggle(S,"Click TP","LCtrl + Clique para teleportar.",clickTPAtivo,function(on) clickTPAtivo=on end)
        PremiumButton(S,"Tecla 5","Abre o menu rapido no alvo atual.",true,function() BZTryQuickMenu(LocalPlayer,Players,Camera,ScreenGui,showTopNotif) end)
        PremiumButton(S,"Salvar Posicao","Salva a posicao atual no estado do hub.",false,function()
            if #tpSaves>=8 then showTopNotif("Limite de 8 saves!",HC.Danger); return end
            local ok,root=pcall(getHRP); if ok then table.insert(tpSaves,root.Position); showTopNotif("Posicao salva",HC.Success) end
        end)
    end)
    SimplePage("Settings","Settings","Temas, sistema e recursos planejados do Zypher.",function(S)
        PremiumButton(S,"Zypher Classic","Trocar para o hub visual Classic.",true,function() applyTheme("Zypher Classic") end)
        PremiumButton(S,"Resetar Personagem","Mata apenas o LocalPlayer.",false,function()
            local char=LocalPlayer.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health=0 elseif char then char:BreakJoints() end
        end)
        PremiumButton(S,"AutoFarm","Em desenvolvimento. Nenhuma automacao ativa.",false,function() showTopNotif("AutoFarm ainda em desenvolvimento",HC.Info) end)
        PremiumButton(S,"Creditos","Zypher Divine integrado como UI separada.",false,function() showTopNotif("Visual Divine preservado",HC.Info) end)
    end)
    for i,name in ipairs({"Home","Combat","Visuals","Player","Settings"}) do MakeTab(name,i) end
    task.defer(function() task.wait(); SetPage("Home") end)
    return ui
end

applyTheme=function(themeName)
    if themeName=="Zypher Divine" then
        HC.ThemeName="Zypher Divine"
        _G.ZyferThemeName=HC.ThemeName
        HC.Accent=Color3.fromRGB(214,173,78); HC.AccentDark=Color3.fromRGB(36,111,226)
        HC.Text=Color3.fromRGB(38,56,92); HC.TextMuted=Color3.fromRGB(116,130,160)
        HC.Info=Color3.fromRGB(36,111,226); HC.Border=Color3.fromRGB(214,219,228)
        Main.Visible=false
        local ui=BZBuildDivineUI()
        if ui and ui.root then ui.root.Visible=hubVisible end
        if ui and ui.main then _G.BZHubMainFrame=ui.main end
    else
        HC.ThemeName="Zypher Classic"
        _G.ZyferThemeName=HC.ThemeName
        HC.Accent=Color3.fromRGB(130,0,255); HC.AccentDark=Color3.fromRGB(90,0,180)
        HC.Background=Color3.fromRGB(14,14,21); HC.Surface=Color3.fromRGB(22,22,34)
        HC.Surface2=Color3.fromRGB(30,30,46); HC.Border=Color3.fromRGB(45,45,65)
        HC.Text=Color3.fromRGB(240,240,255); HC.TextMuted=Color3.fromRGB(140,140,170)
        HC.Info=Color3.fromRGB(80,160,255); HC.TabIconIdle=HC.TextMuted
        HC.TabIconActive=Color3.new(1,1,1); HC.TabIconHover=Color3.fromRGB(255,255,255)
        HC.TabBgActive=HC.Accent; HC.TabBgHover=Color3.fromRGB(70,30,115)
        BZDestroyDivineUI()
        _G.BZHubMainFrame=Main
        Main.Visible=hubVisible
        if ActiveTab then BZSelectTab(ActiveTab,Pages,TabBtns,HC,tw,BZSetTabVisual,HC.TabIconActive,HC.TabIconIdle,HC.TabBgActive) end
    end
end

-- ============================================================
-- ABA VISUAL
-- ============================================================
;(function()
    currentTab="Visual"; local vis=Pages["Visual"]
    criarHeader(vis,"[ ESP ]",1)
    local espMainCard,espBar=baseCard(vis,50,2); local espEstado=true
    local espPill2,_,espSetPill2=criarPill(espMainCard,true)
    local espTRow,_=makeTitleRow(espMainCard,"ESP",56)
    criarInfoBtn(espTRow,"Exibe informacoes visuais acima dos jogadores.")
    local espSLbl=lbl(espMainCard,"Informacoes visuais sobre jogadores",10,nil,HC.TextMuted,1)
    espSLbl.Size=UDim2.new(1,-64,0,14); espSLbl.Position=UDim2.new(0,12,0,30); espSLbl.TextXAlignment=Enum.TextXAlignment.Left
    espBar.BackgroundTransparency=0
    local espSubCont=Instance.new("Frame",vis); espSubCont.Size=UDim2.new(1,0,0,0)
    espSubCont.BackgroundTransparency=1; espSubCont.AutomaticSize=Enum.AutomaticSize.Y; espSubCont.LayoutOrder=3
    local espSubLL=Instance.new("UIListLayout",espSubCont); espSubLL.Padding=UDim.new(0,4); espSubLL.SortOrder=Enum.SortOrder.LayoutOrder
    pad(espSubCont,8,0,0,0)
    espSubCont.Visible=true
    local espMainBtn=Instance.new("TextButton",espMainCard); espMainBtn.Size=UDim2.new(1,0,0,50); espMainBtn.BackgroundTransparency=1; espMainBtn.Text=""; espMainBtn.ZIndex=1
    espMainBtn.MouseButton1Click:Connect(function()
        pT(); espEstado=not espEstado; espSetPill2(espEstado); espAtivo=espEstado
        tw(espBar,{BackgroundTransparency=espEstado and 0 or 1},0.15):Play()
        espSubCont.Visible=espEstado
        showTopNotif("ESP "..(espEstado and "ativado" or "desativado"),espEstado and HC.Accent or HC.Border)
    end)
    table.insert(allToggleSetters,{fn=function()
        espEstado=false; espSetPill2(false); espAtivo=false; espBar.BackgroundTransparency=1
        espSubCont.Visible=false
    end})
    table.insert(allCards,{card=espMainCard,tab="Visual",name="esp",keywords="radar visual jogadores",origParent=vis})
    criarSubToggle(espSubCont,"Nomes","",true,function(on) espNome=on end,2)
    criarSubToggle(espSubCont,"HP","",true,function(on) espHP=on end,3)
    do
        local hlCards={}
        local function setHLControls(on)
            for _,card in ipairs(hlCards) do card.Visible=on end
        end
        criarSubToggle(espSubCont,"Highlight","Contorno e preenchimento dos jogadores",true,function(on)
            espHighlight=on; updateEspHL(); setHLControls(on)
        end,4)
        local c
        c=criarSubToggle(espSubCont,"Contorno","Silhueta ao redor do personagem",true,function(on)
            espHLOutline=on; updateHLColor()
        end,5); table.insert(hlCards,c)
        c=criarSubToggle(espSubCont,"Preenchimento","Cor opcional no corpo do personagem",false,function(on)
            espHLFill=on; updateHLColor()
        end,6); table.insert(hlCards,c)
        c=criarRGBPicker(espSubCont,"Cor do Contorno",espHLOutlineColor,function(col)
            espHLOutlineColor=col; updateHLColor()
        end,7); table.insert(hlCards,c)
        c=criarRGBPicker(espSubCont,"Cor do Preenchimento",espHLFillColor,function(col)
            espHLFillColor=col; updateHLColor()
        end,8); table.insert(hlCards,c)
        c=criarSlider(espSubCont,"Transparencia Contorno","0=visivel | 10=invisivel","Controla apenas a silhueta.",0,10,0,function(v)
            espHLOutlineT=v/10; updateHLColor()
        end,9); table.insert(hlCards,c)
        c=criarSlider(espSubCont,"Transparencia Preenchimento","0=solido | 10=invisivel","Controla apenas a cor interna.",0,10,0,function(v)
            espHLFillT=v/10; updateHLColor()
        end,10); table.insert(hlCards,c)
        setHLControls(true)
    end
    local distColorCard=criarRGBPicker(espSubCont,"Cor da Distancia",espDistColor,function(c) espDistColor=c end,12)
    distColorCard.Visible=false
    criarSubToggle(espSubCont,"Distancia","",false,function(on)
        espDist=on; distColorCard.Visible=on
    end,11)

    criarHeader(vis,"[ CAMERA LIVRE ]",20)
    criarToggleKB(vis,"Camera Livre","WASD | E/Q | Shift=rapido | Ctrl=lento | Scroll=zoom",
        "Congela o personagem e libera a camera. Mouse nao afeta o personagem. Ctrl=lento, Shift=rapido, Scroll=zoom.","freecam",false,
        function() kbGated.freecam=true end,
        function() kbGated.freecam=false; if freecamAtivo then toggleFreecam() end end,21)

    criarHeader(vis,"[ VISAO ]",25)
    criarSoKB(vis,"Visao Sensorial","Destaca inimigos em vermelho por 5s",
        "Escolha uma tecla. Pressione para ativar.","vision",26)
end)()

-- ============================================================
-- ABA PVP
-- ============================================================
;(function()
    currentTab="PVP"; local pvp=Pages["PVP"]

    criarHeader(pvp,"[ AIMBOT ]",1)
    criarToggle(pvp,"Aim Assist","Segure RMB: gruda na mira se tiver alguem | Teleporte do alvo libera",
        "Segure RMB com alguem na mira para travar. Se nao tiver ninguem na FOV, nao grava. Se o alvo teleportar, libera automaticamente.",true,
        function() aimAtivo=true; showTopNotif("Aim Assist ON - segure RMB com alvo na mira",HC.Accent) end,
        function() aimAtivo=false; aimLockedTarget=nil; aimLastPos=nil; showTopNotif("Aim Assist desativado",HC.Border) end,2)
    criarSlider(pvp,"FOV do Aimbot","Raio de deteccao em graus","Quanto menor, mais preciso.",1,20,8,function(v) aimFOV=v end,3)
    criarSlider(pvp,"Suavidade","0=instantaneo | 10=suave","Controla a gradualidade do movimento.",0,10,0,function(v) aimSmooth=v end,4)
    criarToggle(pvp,"Aim em NPC/Boss","Inclui NPCs, bots e bosses no Aim Assist",
        "Quando ativado, o RMB tambem pode travar em Models com Humanoid vivos no workspace. Players continuam funcionando normalmente.",false,
        function() aimNPCAtivo=true; showTopNotif("Aim NPC/Boss ativado",HC.Accent) end,
        function()
            aimNPCAtivo=false
            if aimLockedTarget and aimLockedTarget:IsA("Model") then aimLockedTarget=nil; aimLastPos=nil end
            showTopNotif("Aim NPC/Boss desativado",HC.Border)
        end,5)

    criarHeader(pvp,"[ PASSO FANTASMA ]",10)
    criarSoKB(pvp,"Passo Fantasma","Ative, use 1x (RMB hover + LMB), desativa sozinho | Max: "..maxTlDist.."st",
        "Ative com a tecla. Segure RMB sobre o alvo e clique LMB para teletransportar. Tem limite de distancia. Desativa automaticamente.","tl",11)
    criarSlider(pvp,"Limite de Distancia","Distancia maxima do Passo Fantasma","Se o alvo estiver mais longe, o TP nao ocorre.",10,300,maxTlDist,function(v) maxTlDist=v end,12)
end)()

-- ============================================================
-- ABA SKILLS - FIX 1: Proximity Fling movido para ca
-- ============================================================
;(function()
    currentTab="Skills"; local hab=Pages["Skills"]
    criarHeader(hab,"[ VOO ]",1)
    criarToggleKB(hab,"Voar","WASD para mover | camera controla direcao",
        "Toggle arma. Escolha uma tecla para ativar/desativar.","fly",true,
        function() kbGated.fly=true end,
        function() kbGated.fly=false; if flyAtivo then flyAtivo=false; stopFly() end end,2)
    criarSlider(hab,"Velocidade do Voo","Velocidade base ao voar","Velocidade normal sem Shift.",50,500,50,function(v) flySpeed=v end,3)
    criarSlider(hab,"Boost (Shift)","Velocidade ao segurar Shift","Mantenha Shift para ativar o boost.",100,1000,1000,function(v) flyBoost=v end,4)

    criarHeader(hab,"[ FISICA ]",5)
    do
        local spCard,spBar=baseCard(hab,78,6); local spEstado=false
        local spPill2,_,spSetPill2=criarPill(spCard,false)
        criarKBBtn(spCard,"jump",-56)
        local spTRow,_=makeTitleRow(spCard,"Super Pulo",148)
        criarInfoBtn(spTRow,"Toggle arma. Escolha uma tecla para ativar/desativar.")
        local spSub=lbl(spCard,"Impulso vertical potenciado no pulo",10,nil,HC.TextMuted,1)
        spSub.Size=UDim2.new(1,-156,0,14); spSub.Position=UDim2.new(0,12,0,32); spSub.TextXAlignment=Enum.TextXAlignment.Left
        local spHLbl=lbl(spCard,"Altura:  120",10,nil,HC.Accent,1)
        spHLbl.Size=UDim2.new(0,88,0,14); spHLbl.Position=UDim2.new(0,12,0,53); spHLbl.TextXAlignment=Enum.TextXAlignment.Left
        local hTrack=Instance.new("Frame",spCard); hTrack.Size=UDim2.new(1,-110,0,6); hTrack.Position=UDim2.new(0,104,0,56)
        hTrack.BackgroundColor3=HC.Border; hTrack.BorderSizePixel=0; corner(hTrack,99)
        local hFill=Instance.new("Frame",hTrack); hFill.Size=UDim2.new((120-50)/(500-50),0,1,0); hFill.BackgroundColor3=HC.Accent; hFill.BorderSizePixel=0; corner(hFill,99)
        local hMark=Instance.new("Frame",hTrack); hMark.Size=UDim2.new(0,14,0,14); hMark.AnchorPoint=Vector2.new(0.5,0.5)
        hMark.Position=UDim2.new((120-50)/(500-50),0,0.5,0); hMark.BackgroundColor3=Color3.new(1,1,1); hMark.BorderSizePixel=0; hMark.ZIndex=2; corner(hMark,99)
        local hBtn=Instance.new("TextButton",hTrack); hBtn.Size=UDim2.new(1,0,0,24); hBtn.Position=UDim2.new(0,0,0.5,-12)
        hBtn.BackgroundTransparency=1; hBtn.Text=""; hBtn.ZIndex=3
        hBtn.MouseButton1Down:Connect(function()
            pC(); activeDrag={track=hTrack,fill=hFill,mark=hMark,valLbl=spHLbl,minV=50,maxV=500,
                cb=function(v) jumpHeight=v; spHLbl.Text="Altura:  "..v end}
        end)
        local spTogBtn=Instance.new("TextButton",spCard); spTogBtn.Size=UDim2.new(1,0,0,48); spTogBtn.BackgroundTransparency=1; spTogBtn.Text=""; spTogBtn.ZIndex=1
        spTogBtn.MouseButton1Click:Connect(function()
            pT(); spEstado=not spEstado; spSetPill2(spEstado); kbGated.jump=spEstado
            if not spEstado then superPuloAtivo=false end
            tw(spBar,{BackgroundTransparency=spEstado and 0 or 1},0.15):Play()
            showTopNotif("Super Pulo "..(spEstado and "armado" or "desativado"),spEstado and HC.Accent or HC.Border)
        end)
        table.insert(allCards,{card=spCard,tab="Skills",name="super pulo",keywords="pulo altura salto jump",origParent=hab})
        table.insert(allToggleSetters,{fn=function() spEstado=false; spSetPill2(false); kbGated.jump=false; superPuloAtivo=false; spBar.BackgroundTransparency=1 end})
    end
    do
        local _,setInfJump=criarToggle(hab,"Pulo Infinito","Permite pular novamente mesmo no ar",
            "Ative para liberar saltos consecutivos sem tocar o chao.",false,
            function()
                _G.BZInfJumpAtivo=true
                if _G.BZInfJumpConn then _G.BZInfJumpConn:Disconnect() end
                _G.BZInfJumpConn=UserInputService.JumpRequest:Connect(function()
                    if not _G.BZInfJumpAtivo then return end
                    if _G.BZControlLockState and _G.BZControlLockState.locked then return end
                    local hum=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                end)
                showTopNotif("Pulo Infinito ON",HC.Accent)
            end,
            function()
                local wasOn=_G.BZInfJumpAtivo or _G.BZInfJumpConn
                _G.BZInfJumpAtivo=false
                if _G.BZInfJumpConn then _G.BZInfJumpConn:Disconnect(); _G.BZInfJumpConn=nil end
                if wasOn then showTopNotif("Pulo Infinito OFF",HC.Border) end
            end,7)
        table.insert(allToggleSetters,{fn=function()
            setInfJump(false)
            _G.BZInfJumpAtivo=false
            if _G.BZInfJumpConn then _G.BZInfJumpConn:Disconnect(); _G.BZInfJumpConn=nil end
        end})
    end
    criarHeader(hab,"[ STEALTH ]",10)
    criarToggleKB(hab,"Invisivel","Usa cadeira invisivel para ocultar o personagem",
        "Toggle arma. Escolha uma tecla para ativar/desativar.","invis",true,
        function() kbGated.invis=true end,
        function() kbGated.invis=false; if invisAtivo then invisAtivo=true; toggleInvis() end end,11)
    criarToggleKB(hab,"Noclip","Atravessa paredes e objetos solidos",
        "Toggle arma. Escolha uma tecla para ativar/desativar.","noclip",false,
        function() kbGated.noclip=true end,
        function() kbGated.noclip=false; if noclipAtivo then toggleNoclip() end end,12)

    -- FIX 1: Proximity Fling na aba Skills
    criarHeader(hab,"[ PROXIMITY FLING ]",20)
    criarToggleKB(hab,"Proximity Fling","Arremessa jogadores no raio de deteccao",
        "Arremessa automaticamente todos os jogadores dentro do raio configurado.",
        "fling",false,
        function() kbGated.fling=true end,
        function()
            kbGated.fling=false
            if flingAtivo then
                flingAtivo=false
                workspace.FallenPartsDestroyHeight=flingFPDH
            end
        end,21)
    criarSlider(hab,"Raio do Fling","Distancia maxima para detectar alvos","Jogadores fora desse raio serao ignorados.",5,100,20,
        function(v) flingRadius=v end,22)
end)()

-- ============================================================
-- ABA AUTOFARM
-- ============================================================
;(function()
    currentTab="AutoFarm"; local af=Pages["AutoFarm"]
    local warnCard=Instance.new("Frame",af); warnCard.Size=UDim2.new(1,0,0,76); warnCard.LayoutOrder=0
    warnCard.BackgroundColor3=Color3.fromRGB(30,24,18); warnCard.BorderSizePixel=0; corner(warnCard,9)
    stroke(warnCard,Color3.fromRGB(240,176,56),0.42)
    local wbar=Instance.new("Frame",warnCard)
    wbar.Size=UDim2.new(0,4,1,-18); wbar.Position=UDim2.new(0,0,0,9)
    wbar.BackgroundColor3=Color3.fromRGB(240,176,56); wbar.BorderSizePixel=0; corner(wbar,99)
    local wlbl=lbl(warnCard,"AutoFarm em desenvolvimento",14,Enum.Font.GothamBold,HC.Text,1)
    wlbl.Size=UDim2.new(1,-118,0,22); wlbl.Position=UDim2.new(0,12,0,11); wlbl.TextXAlignment=Enum.TextXAlignment.Left
    local wtag=Instance.new("Frame",warnCard)
    wtag.Size=UDim2.new(0,92,0,22); wtag.AnchorPoint=Vector2.new(1,0)
    wtag.Position=UDim2.new(1,-10,0,10); wtag.BackgroundColor3=Color3.fromRGB(52,38,18); wtag.BorderSizePixel=0
    corner(wtag,99); stroke(wtag,Color3.fromRGB(240,176,56),0.55)
    local wtagText=lbl(wtag,"BETA",9,Enum.Font.GothamBold,Color3.fromRGB(240,176,56),1)
    wtagText.Size=UDim2.new(1,0,1,0); wtagText.TextXAlignment=Enum.TextXAlignment.Center
    local wsub=lbl(warnCard,"Boss Farm em teste fica nesta aba. As demais rotinas ainda estao bloqueadas.",10,Enum.Font.Gotham,HC.TextMuted,1)
    wsub.Size=UDim2.new(1,-20,0,32); wsub.Position=UDim2.new(0,12,0,36); wsub.TextWrapped=true; wsub.TextXAlignment=Enum.TextXAlignment.Left
    BZBuildBossFarmSection(af,1)
    criarHeader(af,"[ MISSOES ]",30)
    criarItemBloqueado(af,"Auto Missao Boss",31)
    criarItemBloqueado(af,"Auto Missao NPC",32)
    criarItemBloqueado(af,"Auto Missao Bijuu",33)
    criarHeader(af,"[ ATRIBUTOS ]",40)
    criarItemBloqueado(af,"Chi",41); criarItemBloqueado(af,"Ninjutsu",42)
    criarItemBloqueado(af,"Taijutsu",43); criarItemBloqueado(af,"HP",44)
    criarHeader(af,"[ PROGRESSAO ]",50); criarItemBloqueado(af,"Auto Rank Up",51)
end)()

-- ============================================================
-- ABA JOGADORES
-- ============================================================
;(function()
    currentTab="Jogadores"; local jogPag=Pages["Jogadores"]
    criarHeader(jogPag,"[ JOGADORES ]",1)
    local _,rBtn=criarBotao(jogPag,"Atualizar Lista","Atualiza a lista de jogadores online",nil,nil,2)
    rBtn.Text="Atualizar"
    local plFrame=Instance.new("Frame",jogPag); plFrame.Size=UDim2.new(1,0,0,0)
    plFrame.BackgroundTransparency=1; plFrame.AutomaticSize=Enum.AutomaticSize.Y; plFrame.LayoutOrder=3
    local pLL=Instance.new("UIListLayout",plFrame); pLL.Padding=UDim.new(0,6); pLL.SortOrder=Enum.SortOrder.LayoutOrder

    local function refreshPlayerList()
        for _,c in pairs(plFrame:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
        local idx=0
        for _,p in ipairs(Players:GetPlayers()) do
            if p==LocalPlayer then continue end; idx=idx+1
            -- Card de jogador com acoes basicas
            local card=Instance.new("Frame",plFrame); card.Size=UDim2.new(1,0,0,62)
            card.BackgroundColor3=HC.Surface2; card.BorderSizePixel=0; card.LayoutOrder=idx; corner(card,8)
            local avatarFrame=Instance.new("Frame",card); avatarFrame.Size=UDim2.new(0,44,0,44)
            avatarFrame.Position=UDim2.new(0,8,0.5,-22); avatarFrame.BackgroundColor3=HC.Surface; avatarFrame.BorderSizePixel=0; corner(avatarFrame,6)
            local avatarImg=Instance.new("ImageLabel",avatarFrame); avatarImg.Size=UDim2.new(1,0,1,0)
            avatarImg.BackgroundTransparency=1; avatarImg.BorderSizePixel=0; corner(avatarImg,6)
            task.spawn(function()
                local ok,img=pcall(function() return Players:GetUserThumbnailAsync(p.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48) end)
                if ok and avatarImg.Parent then avatarImg.Image=img end
            end)
            local robloxNameLbl=lbl(card,p.Name,12,Enum.Font.GothamBold,HC.Text,1)
            robloxNameLbl.Size=UDim2.new(1,-166,0,17); robloxNameLbl.Position=UDim2.new(0,60,0,10)
            robloxNameLbl.TextXAlignment=Enum.TextXAlignment.Left
            local gameNameLbl=lbl(card,p.DisplayName,10,Enum.Font.Gotham,HC.TextMuted,1)
            gameNameLbl.Size=UDim2.new(1,-166,0,14); gameNameLbl.Position=UDim2.new(0,60,0,28)
            gameNameLbl.TextXAlignment=Enum.TextXAlignment.Left
            -- Botao Ver (spectate)
            local specBtn=Instance.new("TextButton",card); specBtn.Size=UDim2.new(0,42,0,24)
            specBtn.AnchorPoint=Vector2.new(1,0.5); specBtn.Position=UDim2.new(1,-8,0.5,0)
            specBtn.BackgroundColor3=HC.Info; specBtn.BorderSizePixel=0; specBtn.Text="Ver"
            specBtn.TextColor3=Color3.new(1,1,1); specBtn.TextSize=10; specBtn.Font=Enum.Font.GothamBold; specBtn.ZIndex=5; corner(specBtn,6)
            specBtn.MouseButton1Click:Connect(function()
                pC()
                if spectateTarget==p then
                    stopSpectate(); specBtn.Text="Ver"; specBtn.BackgroundColor3=HC.Info
                    showTopNotif("Parou de ver "..p.Name,HC.Border)
                else
                    if spectateTarget then
                        for _,c2 in pairs(plFrame:GetChildren()) do
                            if c2:IsA("Frame") then
                                local sb=c2:FindFirstChildOfClass("TextButton")
                                if sb and sb.Text=="Parar" then sb.Text="Ver"; sb.BackgroundColor3=HC.Info end
                            end
                        end
                    end
                    startSpectate(p); specBtn.Text="Parar"; specBtn.BackgroundColor3=HC.Danger
                    showTopNotif("Vendo: "..p.Name.." | Mouse=orbitar | Scroll=zoom",HC.Info)
                end
            end)
            -- Botao TP
            local tpBtn2=Instance.new("TextButton",card); tpBtn2.Size=UDim2.new(0,42,0,24)
            tpBtn2.AnchorPoint=Vector2.new(1,0.5); tpBtn2.Position=UDim2.new(1,-56,0.5,0)
            tpBtn2.BackgroundColor3=HC.Accent; tpBtn2.BorderSizePixel=0; tpBtn2.Text="TP"
            tpBtn2.TextColor3=Color3.new(1,1,1); tpBtn2.TextSize=11; tpBtn2.Font=Enum.Font.GothamBold; tpBtn2.ZIndex=5; corner(tpBtn2,6)
            tpBtn2.MouseButton1Click:Connect(function()
                pC(); local ch=p.Character; if not ch then return end
                local rt=ch:FindFirstChild("HumanoidRootPart"); if not rt then return end
                local ok2,myRoot=pcall(getHRP); if not ok2 then return end
                myRoot.CFrame=rt.CFrame*CFrame.new(0,0,3); showTopNotif("TP -> "..p.Name,HC.Accent)
            end)
            -- Clique no card = copiar nick
            local copyArea=Instance.new("TextButton",card); copyArea.Size=UDim2.new(1,0,1,0)
            copyArea.BackgroundTransparency=1; copyArea.Text=""; copyArea.ZIndex=2
            copyArea.MouseButton1Click:Connect(function()
                pC(); pcall(function() setclipboard(p.Name) end)
                showTopNotif("Nick de "..p.Name.." copiado!",HC.Success)
            end)
            card.MouseEnter:Connect(function() tw(card,{BackgroundColor3=Color3.fromRGB(37,37,55)},0.1):Play() end)
            card.MouseLeave:Connect(function() tw(card,{BackgroundColor3=HC.Surface2},0.1):Play() end)
        end
        if idx==0 then
            local nc=Instance.new("Frame",plFrame); nc.Size=UDim2.new(1,0,0,44); nc.BackgroundColor3=HC.Surface2; nc.BorderSizePixel=0; nc.LayoutOrder=1; corner(nc,8)
            local nl=lbl(nc,"Nenhum jogador encontrado",11,nil,HC.TextMuted,1); nl.Size=UDim2.new(1,0,1,0); nl.TextXAlignment=Enum.TextXAlignment.Center
        end
    end
    rBtn.MouseButton1Click:Connect(function() pC(); refreshPlayerList(); showTopNotif("Lista atualizada",HC.Success) end)
    task.spawn(refreshPlayerList)
    Players.PlayerAdded:Connect(function() task.wait(1); refreshPlayerList() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.5); refreshPlayerList() end)
end)()

-- ============================================================
-- ABA TP
-- ============================================================
;(function()
    currentTab="TP"; local tpPag=Pages["TP"]
    do
        local hero=Instance.new("Frame",tpPag); hero.Size=UDim2.new(1,0,0,58); hero.LayoutOrder=0
        hero.BackgroundColor3=Color3.fromRGB(18,18,32); hero.BorderSizePixel=0; corner(hero,9)
        stroke(hero,HC.Accent,0.55)
        local title=lbl(hero,"Central de Teleporte",13,Enum.Font.GothamBold,HC.Text,1)
        title.Size=UDim2.new(1,-24,0,20); title.Position=UDim2.new(0,12,0,10); title.TextXAlignment=Enum.TextXAlignment.Left
        local sub=lbl(hero,"Click TP e saves organizados para movimentacao rapida.",10,Enum.Font.Gotham,HC.TextMuted,1)
        sub.Size=UDim2.new(1,-24,0,16); sub.Position=UDim2.new(0,12,0,32); sub.TextXAlignment=Enum.TextXAlignment.Left
    end
    criarHeader(tpPag,"[ TELEPORTES ]",1)
    criarToggle(tpPag,"Click TP","LCtrl + Clique para teleportar","Segure LCtrl e clique em qualquer superficie.",false,
        function() clickTPAtivo=true; showTopNotif("Click TP ativado - LCtrl+Clique",HC.Accent) end,
        function() clickTPAtivo=false; showTopNotif("Click TP desativado",HC.Border) end,2)
    criarHeader(tpPag,"[ SEGUIR PLAYER ]",3)
    do
        local followBusy=false
        local card=Instance.new("Frame",tpPag); card.Size=UDim2.new(1,0,0,82); card.LayoutOrder=4
        card.BackgroundColor3=HC.Surface2; card.BorderSizePixel=0; corner(card,8); stroke(card,HC.Info,0.55)
        local title=lbl(card,"Seguir por Nick",13,Enum.Font.GothamBold,HC.Text,1)
        title.Size=UDim2.new(1,-24,0,18); title.Position=UDim2.new(0,12,0,8); title.TextXAlignment=Enum.TextXAlignment.Left
        local sub=lbl(card,"Digite o username correto. Maiuscula/minuscula nao importa.",10,nil,HC.TextMuted,1)
        sub.Size=UDim2.new(1,-24,0,15); sub.Position=UDim2.new(0,12,0,28); sub.TextXAlignment=Enum.TextXAlignment.Left
        local box=Instance.new("TextBox",card)
        box.Size=UDim2.new(1,-114,0,28); box.Position=UDim2.new(0,12,0,48)
        box.BackgroundColor3=HC.Surface; box.BorderSizePixel=0; box.ClearTextOnFocus=false
        box.PlaceholderText="Nick do player"; box.PlaceholderColor3=HC.TextMuted
        box.Text=""; box.TextColor3=HC.Text; box.TextSize=11; box.Font=Enum.Font.Gotham
        box.TextXAlignment=Enum.TextXAlignment.Left; corner(box,6); stroke(box,HC.Border,0.55); pad(box,8,8,0,0)
        local followBtn=Instance.new("TextButton",card)
        followBtn.Size=UDim2.new(0,88,0,28); followBtn.AnchorPoint=Vector2.new(1,0)
        followBtn.Position=UDim2.new(1,-10,0,48); followBtn.BackgroundColor3=HC.Accent; followBtn.BorderSizePixel=0
        followBtn.Text="Seguir"; followBtn.TextColor3=Color3.new(1,1,1); followBtn.TextSize=11; followBtn.Font=Enum.Font.GothamBold
        followBtn.ZIndex=5; corner(followBtn,6)
        local function trimText(v)
            return tostring(v or ""):match("^%s*(.-)%s*$")
        end
        local function findCurrentPlayerByName(nick)
            local q=string.lower(trimText(nick))
            if q=="" then return nil end
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer and string.lower(p.Name)==q then return p end
            end
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer and string.lower(p.DisplayName)==q then return p end
            end
            return nil
        end
        local function setBusy(on)
            followBusy=on
            followBtn.Text=on and "Buscando..." or "Seguir"
            followBtn.BackgroundColor3=on and HC.Border or HC.Accent
        end
        local function followPlayerByName()
            if followBusy then return end
            local nick=trimText(box.Text)
            if nick=="" then showTopNotif("Digite o nick do player",HC.Danger); return end
            local sameServer=findCurrentPlayerByName(nick)
            if sameServer then
                local ch=sameServer.Character
                local rt=ch and ch:FindFirstChild("HumanoidRootPart")
                local ok,myRoot=pcall(getHRP)
                if ok and myRoot and rt then
                    myRoot.CFrame=rt.CFrame*CFrame.new(0,0,4)
                    showTopNotif("Player encontrado neste servidor: "..sameServer.Name,HC.Success)
                else
                    showTopNotif("Player esta no servidor, mas sem personagem carregado",HC.Border)
                end
                return
            end
            setBusy(true)
            task.spawn(function()
                local okId,userId=pcall(function()
                    return Players:GetUserIdFromNameAsync(nick)
                end)
                if not okId or not userId then
                    setBusy(false)
                    showTopNotif("Nick nao encontrado",HC.Danger)
                    return
                end
                if userId==LocalPlayer.UserId then
                    setBusy(false)
                    showTopNotif("Esse e o seu proprio nick",HC.Border)
                    return
                end
                showTopNotif("Procurando servidor do player...",HC.Info)
                local okFind,currentInstance,findErr,placeId,jobId=pcall(function()
                    return TeleportService:GetPlayerPlaceInstanceAsync(userId)
                end)
                if not okFind then
                    setBusy(false)
                    showTopNotif("Roblox bloqueou o local ou o player esta offline",HC.Danger)
                    return
                end
                if currentInstance then
                    setBusy(false)
                    showTopNotif("Player ja esta neste servidor",HC.Success)
                    return
                end
                if not placeId or not jobId or tostring(jobId)=="" then
                    setBusy(false)
                    showTopNotif("Player offline, privado ou sem permissao",HC.Danger)
                    return
                end
                showTopNotif("Entrando no servidor do player...",HC.Accent)
                local okTp,tpErr=pcall(function()
                    TeleportService:TeleportToPlaceInstance(placeId,jobId,LocalPlayer)
                end)
                if not okTp then
                    setBusy(false)
                    showTopNotif("Falha ao teleportar para o amigo",HC.Danger)
                    print("[Zyfer Follow] Teleport erro:",tpErr)
                end
            end)
        end
        followBtn.MouseButton1Click:Connect(function() pC(); followPlayerByName() end)
        box.FocusLost:Connect(function(enterPressed)
            if enterPressed then followPlayerByName() end
        end)
    end
    criarHeader(tpPag,"[ SALVAR POSICAO ]",5)
    local dica=Instance.new("Frame",tpPag); dica.Size=UDim2.new(1,0,0,34); dica.LayoutOrder=6
    dica.BackgroundColor3=Color3.fromRGB(18,28,40); dica.BorderSizePixel=0; corner(dica,6)
    stroke(dica,HC.Info,0.6)
    local dicaL=lbl(dica,"EDIT  Renomeie cada save direto no titulo do card.",10,Enum.Font.GothamSemibold,Color3.fromRGB(130,190,255),1)
    dicaL.Size=UDim2.new(1,-18,1,0); dicaL.Position=UDim2.new(0,10,0,0); dicaL.TextXAlignment=Enum.TextXAlignment.Left
    local tpSaveList=Instance.new("Frame",tpPag); tpSaveList.Size=UDim2.new(1,0,0,0)
    tpSaveList.BackgroundTransparency=1; tpSaveList.AutomaticSize=Enum.AutomaticSize.Y; tpSaveList.LayoutOrder=8
    local tpSL=Instance.new("UIListLayout",tpSaveList); tpSL.Padding=UDim.new(0,6); tpSL.SortOrder=Enum.SortOrder.LayoutOrder
    local _,saveBtn=criarBotao(tpPag,"Salvar Posicao Atual","Maximo de 8 saves","Salva a posicao atual.",
        function()
            if #tpSaves>=8 then showTopNotif("Limite de 8 saves!",HC.Danger); return end
            local ok,root=pcall(getHRP); if not ok then return end
            local pos=root.Position; local idx=#tpSaves+1; table.insert(tpSaves,pos)
            local sCard=Instance.new("Frame",tpSaveList); sCard.Size=UDim2.new(1,0,0,64)
            sCard.BackgroundColor3=HC.Surface2; sCard.BorderSizePixel=0; sCard.LayoutOrder=idx; corner(sCard,8)
            local editHint=lbl(sCard,"E",11,Enum.Font.GothamBold,HC.TextMuted,1)
            editHint.Size=UDim2.new(0,18,0,18); editHint.Position=UDim2.new(0,8,0,9)
            editHint.TextXAlignment=Enum.TextXAlignment.Center
            local sTitleBox=Instance.new("TextBox",sCard)
            sTitleBox.Size=UDim2.new(0,138,0,22); sTitleBox.Position=UDim2.new(0,30,0,7)
            sTitleBox.BackgroundColor3=Color3.fromRGB(20,20,36); sTitleBox.BorderSizePixel=0
            sTitleBox.Text="Save "..idx; sTitleBox.TextSize=12; sTitleBox.Font=Enum.Font.GothamBold
            sTitleBox.TextColor3=HC.Text; sTitleBox.TextXAlignment=Enum.TextXAlignment.Left
            sTitleBox.PlaceholderText="Nome do save"; sTitleBox.PlaceholderColor3=HC.TextMuted
            sTitleBox.ClearTextOnFocus=false; sTitleBox.ZIndex=5; corner(sTitleBox,5); pad(sTitleBox,6,6,0,0)
            stroke(sTitleBox,HC.Accent,0.7)
            sTitleBox.Focused:Connect(function() tw(sTitleBox,{BackgroundColor3=Color3.fromRGB(30,18,55)},0.12):Play() end)
            sTitleBox.FocusLost:Connect(function() tw(sTitleBox,{BackgroundColor3=Color3.fromRGB(20,20,36)},0.12):Play() end)
            local sPosLbl=lbl(sCard,string.format("%.0f, %.0f, %.0f",pos.X,pos.Y,pos.Z),9,nil,HC.TextMuted,1)
            sPosLbl.Size=UDim2.new(1,-170,0,14); sPosLbl.Position=UDim2.new(0,12,0,38); sPosLbl.TextXAlignment=Enum.TextXAlignment.Left
            local tpBtnS=Instance.new("TextButton",sCard); tpBtnS.Size=UDim2.new(0,76,0,24)
            tpBtnS.AnchorPoint=Vector2.new(1,0.5); tpBtnS.Position=UDim2.new(1,-8,0.5,0)
            tpBtnS.BackgroundColor3=HC.Accent; tpBtnS.BorderSizePixel=0; tpBtnS.Text="Teleportar"
            tpBtnS.TextColor3=Color3.new(1,1,1); tpBtnS.TextSize=10; tpBtnS.Font=Enum.Font.GothamBold; tpBtnS.ZIndex=5; corner(tpBtnS,6)
            tpBtnS.MouseButton1Click:Connect(function()
                pC(); local ok2,r=pcall(getHRP); if not ok2 then return end
                r.CFrame=CFrame.new(pos); showTopNotif("TP -> "..sTitleBox.Text,HC.Accent)
            end)
            local delBtnS=Instance.new("TextButton",sCard); delBtnS.Size=UDim2.new(0,30,0,24)
            delBtnS.AnchorPoint=Vector2.new(1,0.5); delBtnS.Position=UDim2.new(1,-90,0.5,0)
            delBtnS.BackgroundColor3=HC.Danger; delBtnS.BorderSizePixel=0; delBtnS.Text="X"
            delBtnS.TextColor3=Color3.new(1,1,1); delBtnS.TextSize=11; delBtnS.Font=Enum.Font.GothamBold; delBtnS.ZIndex=5; corner(delBtnS,6)
            delBtnS.MouseButton1Click:Connect(function() pC(); sCard:Destroy(); table.remove(tpSaves,idx) end)
            sCard.MouseEnter:Connect(function() tw(sCard,{BackgroundColor3=Color3.fromRGB(37,37,55)},0.1):Play() end)
            sCard.MouseLeave:Connect(function() tw(sCard,{BackgroundColor3=HC.Surface2},0.1):Play() end)
            showTopNotif("Posicao "..idx.." salva!",HC.Success)
        end,7)
    saveBtn.Text="Salvar"
end)()

-- ============================================================
-- ABA MISC
-- ============================================================
;(function()
    currentTab="Misc"; local miscPag=Pages["Misc"]
    destruirHubDefinitivo=function()
        showTopNotif("Destruindo hub e limpando estados...",HC.Danger)
        task.delay(0.45,function()
            BZSetHubMouseModal(ScreenGui,UserInputService,false)
            for _,setter in ipairs(allToggleSetters) do pcall(setter.fn) end
            if flyAtivo    then flyAtivo=false;    pcall(stopFly)      end
            if noclipAtivo then noclipAtivo=false; pcall(toggleNoclip) end
            if invisAtivo  then invisAtivo=true;   pcall(toggleInvis)  end
            if freecamAtivo then pcall(toggleFreecam) end
            if spectateTarget then pcall(stopSpectate) end
            if tlModoAtivo then tlClearAll() end
            if flingAtivo then flingAtivo=false; workspace.FallenPartsDestroyHeight=flingFPDH end
            superPuloAtivo=false; aimAtivo=false; aimNPCAtivo=false; clickTPAtivo=false
            aimLockedTarget=nil; aimLastPos=nil
            _G.ZyferBossFarmAimTarget=nil
            BZClearPlayerHighlights()
            BZClearQuickMenu()
            BZClearMarkedPlayer()
            if _G.BZInfJumpConn then pcall(function() _G.BZInfJumpConn:Disconnect() end); _G.BZInfJumpConn=nil end
            _G.BZInfJumpAtivo=false
            kbGated={fly=false,invis=false,jump=false,freecam=false,noclip=false,fling=false}
            useBall=false; janelaTravada=false; hubVisible=false
            mostrarHub=nil; esconderHub=nil; toggleHub=nil
            pcall(function()
                MiniBall.Visible=false
                FpsDisplay.Visible=false
            end)
            pcall(function()
                Camera.CameraType=Enum.CameraType.Custom; Camera.FieldOfView=70
                local myChar=LocalPlayer.Character
                if myChar then
                    local h=myChar:FindFirstChildOfClass("Humanoid")
                    if h then Camera.CameraSubject=h end
                end
            end)
            pcall(function() espFolder:Destroy() end)
            pcall(function() tlSGui:Destroy() end)
            local inv=workspace:FindFirstChild("_BZinvischair")
            if inv then pcall(function() inv:Destroy() end) end
            if fpsConn then pcall(function() fpsConn:Disconnect() end); fpsConn=nil end
            if _G.FLY_LOOP then pcall(function() _G.FLY_LOOP:Disconnect() end); _G.FLY_LOOP=nil end
            _G.BZSession=(_G.BZSession or 0)+1
            _G.ZYFER_MAIN=nil
            _G.BEZALEL_MAIN=nil
            _G.BZFirstLoad=false
            pcall(function() ScreenGui:Destroy() end)
        end)
    end

    criarHeader(miscPag,"[ TEMA ]",1)
    criarBotao(miscPag,"Zypher Classic","Tema atual do hub","Mantem o visual escuro atual sem alterar funcoes.",
        function() applyTheme("Zypher Classic"); showTopNotif("Tema: Zypher Classic",HC.Accent) end,2)
    criarBotao(miscPag,"Zypher Divine","Interface Divine completa e separada","Troca para a UI Divine enviada, mantendo as mesmas funcoes por tras.",
        function() applyTheme("Zypher Divine"); showTopNotif("Tema: Zypher Divine",HC.Info) end,3)

    criarHeader(miscPag,"[ DISPLAY ]",10)
    do
        local fpsCard,fpsBar=baseCard(miscPag,50,11); local fpsEstado=false
        local fpsPill,_,setFpsPill=criarPill(fpsCard,false)
        local fpsTRow,_=makeTitleRow(fpsCard,"Mostrar FPS",56)
        criarInfoBtn(fpsTRow,"FPS no centro superior. Duplo clique no FPS para modo arrastar.")
        local fpsSLbl=lbl(fpsCard,"Centro superior | 2x clique = arrastar",10,nil,HC.TextMuted,1)
        fpsSLbl.Size=UDim2.new(1,-64,0,14); fpsSLbl.Position=UDim2.new(0,12,0,30); fpsSLbl.TextXAlignment=Enum.TextXAlignment.Left
        fpsBar.BackgroundTransparency=1
        local fpsBtnL=Instance.new("TextButton",fpsCard); fpsBtnL.Size=UDim2.new(1,0,0,50); fpsBtnL.BackgroundTransparency=1; fpsBtnL.Text=""; fpsBtnL.ZIndex=1
        fpsBtnL.MouseButton1Click:Connect(function()
            pT(); fpsEstado=not fpsEstado; setFpsPill(fpsEstado); fpsAtivo=fpsEstado
            tw(fpsBar,{BackgroundTransparency=fpsEstado and 0 or 1},0.15):Play()
            FpsDisplay.Visible=fpsEstado
            if fpsEstado then
                if fpsConn then fpsConn:Disconnect() end
                local t2=0; local fr=0
                fpsConn=RunService.RenderStepped:Connect(function(dt)
                    if _G.BZSession~=BZ_SID then fpsConn:Disconnect(); return end
                    fr=fr+1; t2=t2+dt
                    if t2>=0.25 then
                        local fps=math.round(fr/t2); FpsValueLbl.Text=tostring(fps)
                        FpsDot.BackgroundColor3=fps>=55 and HC.Success or fps>=30 and Color3.fromRGB(255,200,0) or HC.Danger
                        t2=0; fr=0
                    end
                end)
                showTopNotif("FPS ativado - centro superior da tela",HC.Success)
            else
                if fpsConn then fpsConn:Disconnect(); fpsConn=nil end
                FpsValueLbl.Text="--"
            end
        end)
        table.insert(allToggleSetters,{fn=function()
            fpsEstado=false; setFpsPill(false); fpsAtivo=false; fpsBar.BackgroundTransparency=1
            FpsDisplay.Visible=false
            if fpsConn then fpsConn:Disconnect(); fpsConn=nil end; FpsValueLbl.Text="--"
        end})
        table.insert(allCards,{card=fpsCard,tab="Misc",name="mostrar fps",keywords="fps frames tela counter",origParent=miscPag})
    end

    criarHeader(miscPag,"[ SISTEMA ]",20)
    do
        local resetConfirm=0
        criarBotao(miscPag,"Resetar Personagem","Clique 2x para matar seu personagem atual","Afeta apenas o LocalPlayer.",
            function()
                local now=tick()
                if now-resetConfirm>3 then
                    resetConfirm=now
                    showTopNotif("Clique novamente para confirmar reset",HC.Danger)
                    return
                end
                resetConfirm=0
                local char=LocalPlayer.Character
                local hum=char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.Health=0
                elseif char then
                    char:BreakJoints()
                end
                showTopNotif("Personagem resetado",HC.Danger)
            end,21)
    end
    criarBotao(miscPag,"Rejoin","Reconectar ao mesmo servidor","Recarrega no mesmo servidor atual.",
        function()
            showTopNotif("Reconectando ao servidor...",HC.Info)
            task.delay(2.2,function()
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,LocalPlayer)
                end)
            end)
        end,22)
    criarBotao(miscPag,"Destruir Hub","Desativa tudo e fecha definitivamente","Limpa estados ativos, remove objetos criados e nao reabre automaticamente.",
        function()
            destruirHubDefinitivo()
        end,23)
    criarBotao(miscPag,"Reiniciar Hub","Desfaz tudo, se destroi e reabre do zero","Reseta todos os estados e reinicia o script.",
        function()
            showTopNotif("Reiniciando hub...",HC.Info)
            task.delay(0.6,function()
                for _,setter in ipairs(allToggleSetters) do pcall(setter.fn) end
                if flyAtivo    then flyAtivo=false;    pcall(stopFly)      end
                if noclipAtivo then noclipAtivo=false; pcall(toggleNoclip) end
                if invisAtivo  then invisAtivo=true;   pcall(toggleInvis)  end
                if freecamAtivo then pcall(toggleFreecam) end
                if spectateTarget then pcall(stopSpectate) end
                if tlModoAtivo then tlClearAll() end
                if flingAtivo then flingAtivo=false; workspace.FallenPartsDestroyHeight=flingFPDH end
                superPuloAtivo=false; aimAtivo=false; aimNPCAtivo=false; clickTPAtivo=false
                aimLockedTarget=nil; aimLastPos=nil
                _G.ZyferBossFarmAimTarget=nil
                BZClearPlayerHighlights()
                BZClearQuickMenu()
                BZClearMarkedPlayer()
                if _G.BZInfJumpConn then pcall(function() _G.BZInfJumpConn:Disconnect() end); _G.BZInfJumpConn=nil end
                _G.BZInfJumpAtivo=false
                kbGated={fly=false,invis=false,jump=false,freecam=false,noclip=false,fling=false}
                pcall(function()
                    Camera.CameraType=Enum.CameraType.Custom; Camera.FieldOfView=70
                    local myChar=LocalPlayer.Character
                    if myChar then
                        local h=myChar:FindFirstChildOfClass("Humanoid")
                        if h then Camera.CameraSubject=h end
                    end
                end)
                pcall(function() espFolder:Destroy() end)
                pcall(function() tlSGui:Destroy() end)
                local inv=workspace:FindFirstChild("_BZinvischair")
                if inv then pcall(function() inv:Destroy() end) end
                task.wait(0.1)
                BZSetHubMouseModal(ScreenGui,UserInputService,false)
                pcall(function() ScreenGui:Destroy() end)
                _G.BZSession=(_G.BZSession or 0)+1
                if _G.FLY_LOOP then pcall(function() _G.FLY_LOOP:Disconnect() end); _G.FLY_LOOP=nil end
                if _G.ZYFER_MAIN then _G.ZYFER_MAIN() elseif _G.BEZALEL_MAIN then _G.BEZALEL_MAIN() end
            end)
        end,24)
end)()

-- ============================================================
-- ABA CREDITOS
-- ============================================================
;(function()
    currentTab="Creditos"; local cPag=Pages["Creditos"]
    BZBuildCreditsPortfolio(cPag,HC,corner,stroke,lbl)
end)()

-- ============================================================
-- INPUT HANDLER
-- FIX 11: gating por tecla Z (transformacao) - enquanto Z pressionado, hotkeys do hub nao ativam
-- FIX 2: RMB one-shot lock para aimbot
-- ============================================================
UserInputService.InputBegan:Connect(function(input,gameProcessed)
    if _G.BZSession~=BZ_SID then return end
    if input.KeyCode==KB.hub then if toggleHub then toggleHub() end; return end

    if kbEscutando then
        if input.UserInputType==Enum.UserInputType.Keyboard then
            kbEscutando=false
            if kbCb then kbCb(input.KeyCode==Enum.KeyCode.Escape and Enum.KeyCode.Unknown or input.KeyCode); kbCb=nil end
        end
        return
    end

    if input.UserInputType==Enum.UserInputType.Keyboard and (input.KeyCode==Enum.KeyCode.Five or tostring(input.KeyCode):find("KeypadFive")) then
        if not UserInputService:GetFocusedTextBox() and not UserInputService:IsKeyDown(Enum.KeyCode.Z) then
            BZTryQuickMenu(LocalPlayer,Players,Camera,ScreenGui,showTopNotif)
        end
        return
    end

    -- FIX 2: RMB press - aimbot one-shot scan
    if input.UserInputType==Enum.UserInputType.MouseButton2 then
        if aimAtivo then
            -- Scan unico no momento do press
            aimLockedTarget=aimFindTarget()   -- nil = ninguem encontrado; nao vai grudar
            aimLastPos=nil
        end
        if tlAtivo and tlModoAtivo then tlRmbHeld=true end
        return  -- nao processa como tecla de hub
    end

    if gameProcessed then return end

    -- FIX 11: Se Z estiver pressionado (transformacao), ignora teclas do hub
    if UserInputService:IsKeyDown(Enum.KeyCode.Z) then return end

    local key=input.KeyCode
    if key~=Enum.KeyCode.Unknown then
        local msgs={}; local lastOn=false

        if key==KB.fly and kbGated.fly then
            flyAtivo=not flyAtivo
            if flyAtivo then startFly() else stopFly() end
            table.insert(msgs,"Voar "..(flyAtivo and "ON" or "OFF")); lastOn=flyAtivo
        end
        if key==KB.invis and kbGated.invis then
            toggleInvis()
            table.insert(msgs,"Invisivel "..(invisAtivo and "ON" or "OFF")); lastOn=invisAtivo
        end
        if key==KB.jump and kbGated.jump then
            superPuloAtivo=not superPuloAtivo
            table.insert(msgs,"Super Pulo "..(superPuloAtivo and "ON" or "OFF")); lastOn=superPuloAtivo
        end
        if key==KB.freecam and kbGated.freecam and not freecamAtivo then
            toggleFreecam()
            table.insert(msgs,"Camera Livre ON"); lastOn=true
        end
        if key==KB.noclip and kbGated.noclip then
            toggleNoclip()
            table.insert(msgs,"Noclip "..(noclipAtivo and "ON" or "OFF")); lastOn=noclipAtivo
        end
        if key==KB.vision then
            task.spawn(ativarVisao)
            table.insert(msgs,"Visao Sensorial ativada"); lastOn=true
        end
        if key==KB.tl then
            tlModoAtivo=not tlModoAtivo; tlSetMode(tlModoAtivo)
            if not tlModoAtivo then tlClearAll() end
            table.insert(msgs,"Passo Fantasma "..(tlModoAtivo and "ON" or "OFF")); lastOn=tlModoAtivo
        end
        if key==KB.fling and kbGated.fling then
            flingAtivo=not flingAtivo
            if not flingAtivo then workspace.FallenPartsDestroyHeight=flingFPDH end
            table.insert(msgs,"Proximity Fling "..(flingAtivo and "ON - Raio: "..flingRadius.."st" or "OFF"))
            lastOn=flingAtivo
        end

        if #msgs>0 then
            showTopNotif(table.concat(msgs," + "),lastOn and HC.Accent or HC.Border)
        end
    end

    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        if tlAtivo and tlModoAtivo and tlRmbHeld and tlHovered then
            local char=tlHovered.Character; if not char then return end
            local root2=char:FindFirstChild("HumanoidRootPart"); if not root2 then return end
            local ok,myRoot=pcall(getHRP); if not ok then return end
            -- FIX 7: Verifica distancia antes de teletransportar
            local dist=(root2.Position-myRoot.Position).Magnitude
            if dist>maxTlDist then
                showTopNotif("Passo Fantasma: muito longe! ("..math.floor(dist).."st > "..maxTlDist.."st max)",HC.Danger)
                tlClearAll()
                return
            end
            pcall(function() tlSnd:Play() end)
            myRoot.CFrame=root2.CFrame*CFrame.new(0,0,3)
            showTopNotif("TP -> "..tlHovered.Name.." | Passo Fantasma desativado",HC.Accent)
            tlClearAll()
            return
        end
        if clickTPAtivo and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            local mouse=LocalPlayer:GetMouse()
            if mouse.Target then
                local pos=mouse.Hit.Position+Vector3.new(0,3,0)
                local ok,root=pcall(getHRP); if not ok then return end
                root.CFrame=CFrame.new(pos); showTopNotif("Click TP",HC.Accent)
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if _G.BZSession~=BZ_SID then return end
    if input.UserInputType==Enum.UserInputType.MouseButton2 then
        tlRmbHeld=false
        -- FIX 2: solta o lock do aimbot ao soltar RMB
        if aimAtivo then aimLockedTarget=nil; aimLastPos=nil end
    end
    if input.UserInputType==Enum.UserInputType.MouseButton1 then activeDrag=nil end
end)

-- Drag handler (sliders)
RunService.RenderStepped:Connect(function()
    if _G.BZSession~=BZ_SID then return end
    if not activeDrag then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then activeDrag=nil; return end
    local mouse=UserInputService:GetMouseLocation()
    local track=activeDrag.track
    if not track or not track.Parent then activeDrag=nil; return end
    local abs=track.AbsolutePosition; local w=track.AbsoluteSize.X
    local ratio=math.clamp((mouse.X-abs.X)/w,0,1)
    if activeDrag.isRaw then
        if activeDrag.cb then activeDrag.cb(ratio) end
    else
        local minV=activeDrag.minV; local maxV=activeDrag.maxV
        local val=math.round(minV+(maxV-minV)*ratio)
        if activeDrag.fill then activeDrag.fill.Size=UDim2.new(ratio,0,1,0) end
        if activeDrag.mark then activeDrag.mark.Position=UDim2.new(ratio,0,0.5,0) end
        if activeDrag.valLbl then
            local txt=activeDrag.valLbl.Text
            activeDrag.valLbl.Text=txt:find("Altura") and "Altura:  "..val or tostring(val)
        end
        if activeDrag.cb then activeDrag.cb(val) end
    end
end)

-- HUB SHOW/HIDE
hubVisible=false
mostrarHub=function()
    BZSetHubMouseModal(ScreenGui,UserInputService,true)
    hubVisible=true
    if HC.ThemeName=="Zypher Divine" then
        Main.Visible=false
        local ui=BZBuildDivineUI()
        if ui and ui.root then ui.root.Visible=true end
        pO()
    else
        Main.Visible=true; applyResponsiveLayout(); Main.Size=UDim2.new(0,0,0,0)
        setHubSize(hubW,hubH,true,0.28,Enum.EasingStyle.Back); pO()
    end
    MiniBall.Visible=false
end
esconderHub=function()
    BZSetHubMouseModal(ScreenGui,UserInputService,false)
    hubVisible=false
    applyResponsiveLayout()
    local ui=_G.ZyferDivineUI
    if ui and ui.root then ui.root.Visible=false end
    tw(Main,{Size=UDim2.new(0,hubW,0,0)},0.2):Play()
    task.delay(0.25,function()
        if not hubVisible then
            Main.Visible=false
            if useBall then
                MiniBall.Visible=true
                tw(MiniBall,{Size=UDim2.new(0,72,0,72)},0.25,Enum.EasingStyle.Back):Play()
            end
        end
    end)
end
toggleHub=function() if hubVisible then esconderHub() else mostrarHub() end end

BtnClose.MouseButton1Click:Connect(function()
    pC()
    if destruirHubDefinitivo then
        destruirHubDefinitivo()
    end
end)
BtnMin.MouseButton1Click:Connect(function()
    pC(); esconderHub()
    task.delay(0.4,function()
        if not useBall then showTopNotif("Hub minimizado - pressione Backquote para abrir",HC.Info) end
    end)
end)

-- Arrastar janela
BZWireMainDrag(TopBar,Main,UserInputService,function() return janelaTravada end)

-- Resize
BZWireResize(ResizeHandle,Main,UserInputService,function() return janelaTravada end,getViewportSize,setHubSize,{minW=HUB_MIN_W,minH=HUB_MIN_H,maxW=HUB_MAX_W,maxH=HUB_MAX_H,margin=HUB_MARGIN})

-- Pesquisa
SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    local q=string.lower(SearchInput.Text)
    if q=="" then
        SearchResultsPage.Visible=false
        for _,card in ipairs(allCards) do
            if card.origParent and card.card.Parent==SearchResultsPage then
                card.card.Parent=card.origParent
            end
        end
        for n,p in pairs(Pages) do p.Visible=(n==ActiveTab) end; return
    end
    SearchResultsPage.Visible=true
    for _,p in pairs(Pages) do p.Visible=false end
    for _,card in ipairs(allCards) do
        if card.name:find(q,1,true) or card.keywords:find(q,1,true) then
            card.card.Parent=SearchResultsPage
        else
            if card.origParent and card.card.Parent==SearchResultsPage then
                card.card.Parent=card.origParent
            end
        end
    end
end)

trocarAba("Visual")
applyResponsiveLayout()
Main.Size=UDim2.new(0,hubW,0,hubH)
Main.Visible=false
BZSetHubMouseModal(ScreenGui,UserInputService,false)
showTopNotif("Zyfer em execucao",HC.Success)

-- FIX 3: Fade-in gradual das abas apos o hub abrir
task.spawn(function()
    task.wait(0.55)
    for _,tabName in ipairs(TabNames) do
        local page=Pages[tabName]; if not page then continue end
        local children=page:GetChildren()
        for _,child in ipairs(children) do
            if child:IsA("Frame") and child.BackgroundTransparency<0.9 then
                local origT=child.BackgroundTransparency
                child.BackgroundTransparency=1
                tw(child,{BackgroundTransparency=origT},0.18,Enum.EasingStyle.Quad):Play()
                task.wait(0.025)
            end
        end
    end
end)

end -- ZYFER_MAIN

_G.ZYFER_MAIN=ZYFER_MAIN
_G.BEZALEL_MAIN=ZYFER_MAIN

_G.BZFirstLoad=true
ZYFER_MAIN()
