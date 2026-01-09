<GameFile>
  <PropertyGroup Name="LoadingLayer" Type="Layer" ID="d1100e00-254a-4bb5-8ff0-21e04c6a3ea5" Version="3.10.0.0" />
  <Content ctype="GameProjectContent">
    <Content>
      <Animation Duration="0" Speed="1.0000" />
      <ObjectData Name="Layer" Tag="9" ctype="GameLayerObjectData">
        <Size X="1280.0000" Y="720.0000" />
        <Children>
          <AbstractNodeData Name="bg" ActionTag="91348901" Tag="10" IconVisible="False" PositionPercentXEnabled="True" PositionPercentYEnabled="True" TouchEnable="True" LeftEage="237" RightEage="237" TopEage="237" BottomEage="237" Scale9OriginX="237" Scale9OriginY="237" Scale9Width="806" Scale9Height="246" ctype="ImageViewObjectData">
            <Size X="1280.0000" Y="720.0000" />
            <AnchorPoint ScaleX="0.5000" ScaleY="0.5000" />
            <Position X="640.0000" Y="360.0000" />
            <Scale ScaleX="1.0000" ScaleY="1.0000" />
            <CColor A="255" R="255" G="255" B="255" />
            <PrePosition X="0.5000" Y="0.5000" />
            <PreSize X="1.0000" Y="1.0000" />
            <FileData Type="Normal" Path="boot/resource/imgs/bg.jpg" Plist="" />
          </AbstractNodeData>
          <AbstractNodeData Name="content_panel" ActionTag="11507604" Tag="11" IconVisible="False" PositionPercentXEnabled="True" LeftMargin="340.0000" RightMargin="340.0000" TopMargin="520.0000" TouchEnable="True" ClipAble="False" BackColorAlpha="102" ColorAngle="90.0000" Scale9Width="1" Scale9Height="1" ctype="PanelObjectData">
            <Size X="600.0000" Y="200.0000" />
            <Children>
              <AbstractNodeData Name="bg_bar" ActionTag="-631414337" Tag="27" IconVisible="False" PositionPercentXEnabled="True" PositionPercentYEnabled="True" LeftMargin="-29.5000" RightMargin="-29.5000" TopMargin="54.0000" BottomMargin="54.0000" LeftEage="143" RightEage="143" TopEage="9" BottomEage="9" Scale9OriginX="143" Scale9OriginY="9" Scale9Width="373" Scale9Height="74" ctype="ImageViewObjectData">
                <Size X="659.0000" Y="92.0000" />
                <AnchorPoint ScaleX="0.5000" ScaleY="0.5000" />
                <Position X="300.0000" Y="100.0000" />
                <Scale ScaleX="1.0000" ScaleY="1.0000" />
                <CColor A="255" R="255" G="255" B="255" />
                <PrePosition X="0.5000" Y="0.5000" />
                <PreSize X="1.0983" Y="0.4600" />
                <FileData Type="MarkedSubImage" Path="boot/resource/plist/jdt_1.png" Plist="boot/resource/plist.plist" />
              </AbstractNodeData>
              <AbstractNodeData Name="loading_bar" ActionTag="1470181620" Tag="12" IconVisible="False" PositionPercentXEnabled="True" LeftMargin="-12.5000" RightMargin="-12.5000" TopMargin="71.0000" BottomMargin="73.0000" ProgressInfo="100" ctype="LoadingBarObjectData">
                <Size X="625.0000" Y="56.0000" />
                <AnchorPoint ScaleX="0.5000" ScaleY="0.5000" />
                <Position X="300.0000" Y="101.0000" />
                <Scale ScaleX="1.0000" ScaleY="1.0000" />
                <CColor A="255" R="255" G="255" B="255" />
                <PrePosition X="0.5000" Y="0.5050" />
                <PreSize X="1.0417" Y="0.2800" />
                <ImageFileData Type="MarkedSubImage" Path="boot/resource/plist/jdt_2.png" Plist="boot/resource/plist.plist" />
              </AbstractNodeData>
              <AbstractNodeData Name="text_tip" ActionTag="2113574925" Tag="17" IconVisible="False" PositionPercentXEnabled="True" LeftMargin="201.0000" RightMargin="201.0000" TopMargin="24.0000" BottomMargin="140.0000" FontSize="36" LabelText="LOADGING..." OutlineSize="3" OutlineEnabled="True" ShadowOffsetX="2.0000" ShadowOffsetY="-2.0000" ctype="TextObjectData">
                <Size X="198.0000" Y="36.0000" />
                <AnchorPoint ScaleX="0.5000" />
                <Position X="300.0000" Y="140.0000" />
                <Scale ScaleX="1.0000" ScaleY="1.0000" />
                <CColor A="255" R="255" G="255" B="255" />
                <PrePosition X="0.5000" Y="0.7000" />
                <PreSize X="0.3300" Y="0.1800" />
                <FontResource Type="Default" Path="" Plist="" />
                <OutlineColor A="255" R="26" G="26" B="26" />
                <ShadowColor A="255" R="0" G="0" B="0" />
              </AbstractNodeData>
              <AbstractNodeData Name="text_tip_ttf" ActionTag="-313791629" Tag="19" IconVisible="False" PositionPercentXEnabled="True" LeftMargin="212.0000" RightMargin="212.0000" TopMargin="19.0000" BottomMargin="140.0000" FontSize="30" LabelText="LOADING..." OutlineSize="2" OutlineEnabled="True" ShadowOffsetX="2.0000" ShadowOffsetY="-2.0000" ctype="TextObjectData">
                <Size X="176.0000" Y="41.0000" />
                <AnchorPoint ScaleX="0.5000" />
                <Position X="300.0000" Y="140.0000" />
                <Scale ScaleX="1.0000" ScaleY="1.0000" />
                <CColor A="255" R="255" G="255" B="255" />
                <PrePosition X="0.5000" Y="0.7000" />
                <PreSize X="0.2933" Y="0.2050" />
                <FontResource Type="Normal" Path="boot/resource/fonts/montserrat_bold.ttf" Plist="" />
                <OutlineColor A="255" R="26" G="26" B="26" />
                <ShadowColor A="255" R="110" G="110" B="110" />
              </AbstractNodeData>
              <AbstractNodeData Name="text_speed" ActionTag="546681456" Tag="18" IconVisible="False" PositionPercentXEnabled="True" LeftMargin="142.5000" RightMargin="142.5000" TopMargin="138.0000" BottomMargin="28.0000" FontSize="25" LabelText="1.5MB/3.35MB (128KB/S)" OutlineSize="2" OutlineEnabled="True" ShadowOffsetX="2.0000" ShadowOffsetY="-2.0000" ctype="TextObjectData">
                <Size X="315.0000" Y="34.0000" />
                <AnchorPoint ScaleX="0.5000" ScaleY="0.5000" />
                <Position X="300.0000" Y="45.0000" />
                <Scale ScaleX="1.0000" ScaleY="1.0000" />
                <CColor A="255" R="255" G="255" B="255" />
                <PrePosition X="0.5000" Y="0.2250" />
                <PreSize X="0.5250" Y="0.1700" />
                <FontResource Type="Normal" Path="boot/resource/fonts/montserrat_bold.ttf" Plist="" />
                <OutlineColor A="255" R="214" G="47" B="148" />
                <ShadowColor A="255" R="110" G="110" B="110" />
              </AbstractNodeData>
            </Children>
            <AnchorPoint ScaleX="0.5000" />
            <Position X="640.0000" />
            <Scale ScaleX="1.0000" ScaleY="1.0000" />
            <CColor A="255" R="255" G="255" B="255" />
            <PrePosition X="0.5000" />
            <PreSize X="0.4688" Y="0.2778" />
            <SingleColor A="255" R="150" G="200" B="255" />
            <FirstColor A="255" R="150" G="200" B="255" />
            <EndColor A="255" R="255" G="255" B="255" />
            <ColorVector ScaleY="1.0000" />
          </AbstractNodeData>
        </Children>
      </ObjectData>
    </Content>
  </Content>
</GameFile>