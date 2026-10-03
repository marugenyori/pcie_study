import Foundation

extension QuizDetails {
    // MARK: - 上級（9〜12章）

    static let advanced: [(String, String)] = [
        // 9. LTSSM
        d("ltssm-1", "相手の世代は話してみるまでわからないので、まず全世代が話せる**2.5 GT/s**でL0まで進みます。そのあとTS1/TS2で対応速度を伝え合い、Recoveryを通って速い速度に切り替えます。8.0 GT/s以上では、切り替えのときにイコライゼーションも行います。"),
        d("ltssm-2", "Configurationでは、ダウンストリームポートがリンク番号とレーン番号を提案し、アップストリームポートがそれを受け入れて、リンク幅を決めます（Linkwidth → Lanenum → Complete → Idle）。レーンの逆順（Lane Reversal）もここで判明します。"),
        d("ltssm-3", "Detectでは、送信側が電圧を少し変えて、その変化の速さから相手の受信器の終端（負荷）があるかを調べます。終端が見つかったレーンだけで、次のPollingに進みます。何もつながっていなければ、Detectを繰り返します。"),
        d("ltssm-4", "L0sは片方向ずつ送信を止める浅い省電力状態です。戻るときは**FTS**（Fast Training Sequence）を送って、受信側にビットとシンボルの同期を取り直してもらい、そのままL0に戻ります。失敗したときだけRecoveryに入ります。L0sとFTSはNon-Flit Modeだけの仕組みです。"),
        d("ltssm-5", "Detect.Quietでは、12 ms待つか、受信レーンでElectrical Idleが終わったことを検出すると、Detect.Activeに進みます。Detect.Activeで相手の受信器を調べ、見つからなければDetect.Quietに戻ります。"),
        d("ltssm-6", "Polling.Activeでは、少なくとも**1024個のTS1**を送ります。その間に、すべてのレーンで連続8個のトレーニングシーケンスを受け取れたら、Polling.Configurationに進みます。たくさん送るのは、相手がビットとシンボルの同期を取るのに十分な時間を与えるためです。"),
        d("ltssm-7", "Polling.ConfigurationではTS2を送り合い、相手からTS2を連続8個受け取ったらConfigurationに進みます。48 ms以内に進めなければ、Detectに戻ってやり直します。"),
        d("ltssm-8", "Hot Resetは、リンクを通して下流のデバイスをリセットする状態です。上位層から「Hot Resetを続けて」という指示がなければ、**2 ms**でDetectに移り、リンクの初期化からやり直します。"),
        d("ltssm-9", "Polling.Speedは、昔の仕様で「Pollingの中で速度を変える」ための状態でした。今は、必ず2.5 GT/sでL0に到達してからRecoveryで速度を変えるので、Polling.Speedには**到達しない**と明記されています。"),
        d("ltssm-10", "Configuration.Idleで、物理層の変数**LinkUp**が1になります。これを受けて、データリンク層がフロー制御の初期化を始めます（DL_Init）。データリンク層の状態（DL_Up/DL_Active）とは別のものです。"),
        d("ltssm-11", "LTSSMの主な状態は、Detect・Polling・Configuration・L0・Recovery・L0s・L1・L2・Disabled・Loopback・Hot Resetです。Gen6からはL0pも加わりました。「Transmit」という状態はありません。"),
        d("ltssm-12", "**Recovery**は、L0で動いているリンクを立て直す状態です。速度の変更、イコライゼーション、同期が外れたときの再同期、L1からの復帰、リンク幅の変更などで使われます。終わるとL0に戻ります。"),
        d("ltssm-13", "8.0 GT/s以上の速度に上げるときは、Recovery.Speedで速度を変えたあと、**Recovery.Equalization**で送信側の設定（プリセットや係数）を調整します。Phase 0〜3の手順で、両端が最適な設定を探します。"),
        d("ltssm-14", "Polling.Complianceでは、測定器で送信波形を確かめるための決まったパターン（コンプライアンスパターン）を送り続けます。Link Control 2のEnter Complianceビットが1のときや、受信器は見つかったのにTS1の交換が進まないとき（試験用の治具につないだときなど）に入ります。"),
        d("ltssm-15", "Loopbackでは、片方（Loopback Lead）が送ったデータを、もう片方（Loopback Follower）がそのまま送り返します。送ったデータと返ってきたデータを比べて、ビット誤りの試験などに使います。"),
        d("ltssm-16", "多くの状態では、まず**TS1**を交換してトレーニングを進め、条件がそろったら**TS2**を送り合って「次に進む準備ができた」ことを確かめます。両方がTS2を受け取ったら、次の状態に進みます。"),

        // 10. コンフィグ空間
        d("cfg-1", "各Functionは4KBのコンフィグ空間を持ちます。先頭256バイトは旧PCIと互換で、ヘッダ（64バイト）とPCI互換のCapabilityが入ります。100h〜FFFhはPCIeで追加された拡張領域で、AERやSR-IOVなどの拡張Capabilityが入ります。"),
        d("cfg-2", "ECAMのアドレスは、Base + (Bus << 20) + (Device << 15) + (Function << 12) + オフセット です。Bus 1なら 1 << 20 = 0x00100000。Device 1なら0x8000、Function 1なら0x1000ずつずれます。"),
        d("cfg-3", "読み戻した値の下位の0のビットが、サイズを表します。FFF00000hを反転すると000FFFFFh、1を足すと00100000h＝**1MB**です。BARの領域は必ずサイズの境界に置くので、こうしてサイズがわかります。"),
        d("cfg-4", "存在しないFunctionにコンフィグリクエストを送ると、応答側がいないためUnsupported Requestになり、Root Complexはソフトウェアに**オール1**（FFFFh）を返します。Vendor IDにFFFFhは割り当てられていないので、ソフトウェアは「そこには何もない」と判断できます。"),
        d("cfg-5", "Root Portやスイッチのポートなど、ブリッジは**Type 1**ヘッダを持ちます。BARは2つしかない代わりに、バス番号の範囲（Primary/Secondary/Subordinate）や、下流へ転送するアドレスの範囲（Memory Base/Limitなど）を持っています。"),
        d("cfg-6", "1つのFunctionは4KB、1つのDeviceは8 Function × 4KB = 32KB、1つのバスは32 Device × 32KB = **1MB**です。256本のバスをすべて使うと256MBになります。"),
        d("cfg-7", "Type 0ヘッダでは、10h〜24hにBAR0〜BAR5の6つが並びます。64ビットのBARは隣の2つを使うので、64ビットBARなら最大3つです。"),
        d("cfg-8", "34hのCapabilities Pointerには、最初のCapabilityの場所が入っています。各Capabilityには次の場所が書かれているので、連結リストのようにたどれます。PCIeの拡張Capabilityは100hから始まる別のリストです。"),
        d("cfg-9", "Header Typeレジスタのbit 7が1なら**Multi-Function Device**で、Function 0以外にもFunctionがある可能性を示します。ソフトウェアはbit 7が0なら、Function 1〜7を探さずに済みます。bit 6:0はヘッダの種類（00h=Type 0、01h=Type 1）です。"),
        d("cfg-10", "Type 1ヘッダでは、18hがPrimary、19hがSecondary、1AhがSubordinate Bus Numberです。列挙のとき、ソフトウェアはここにバス番号を書き込んで、ブリッジに転送する範囲を教えます。"),
        d("cfg-11", "00hがVendor ID（16ビット）、02hがDevice ID（16ビット）です。Vendor IDはPCI-SIGが各社に割り当てる番号で、たとえばIntelは8086hです。"),
        d("cfg-12", "**Memory Space Enable**が0のままだと、デバイスはBARで割り当てたメモリ領域へのアクセスに応答しません。OSはBARにアドレスを割り当てたあと、このビットを1にしてデバイスを使えるようにします。"),
        d("cfg-13", "**Bus Master Enable**が0だと、デバイスは自分からメモリにアクセス（DMA）できず、MSI/MSI-Xの割り込みも出せません（MSIもメモリ書き込みだからです）。ドライバは初期化のときにこのビットを1にします。"),
        d("cfg-14", "100hからFFFhまでがPCIeの拡張コンフィグ空間です。旧PCIのI/Oポート方式（CF8h/CFCh）では256バイトまでしか届かないので、拡張領域にはECAMでアクセスします。"),
        d("cfg-15", "64ビットのBARは、下位32ビットと上位32ビットで隣り合う2つのBARを使います。BARの下位ビット（bit 2:1）が10bなら64ビットBARです。サイズを調べるときは、両方に全1を書いて64ビットで計算します。"),
        d("cfg-16", "ECAMのアドレスは、bit 20〜27がBus、bit 15〜19がDevice、bit 12〜14がFunction、bit 0〜11がレジスタのオフセット（4KB分）です。Functionの3ビットが、ちょうど4KB単位の位置に入ります。"),

        // 11. 割り込みと電源管理
        d("int-1", "MSI-XのTable Sizeフィールドは11ビットで、N−1の形で書かれているので、最大2048ベクタです。ベクタごとに別々のCPUに割り込みを振り分けられるので、たくさんのキューを持つNICやNVMeで使われます。"),
        d("int-2", "MSIは、決められたアドレスに決められたデータを書き込む**Memory Write TLP**です。Root Complexがそのアドレスへの書き込みを受け取ると、CPUへの割り込みに変えます。通常のデータと同じ経路・同じ順序規則で届くので、「データを書いてから割り込む」と順番が保たれます。"),
        d("int-3", "**ASPM**（Active State Power Management）は、リンクが一定時間アイドルだとハードウェアが自動でL0sやL1に入れる仕組みです。ソフトウェアの介入なしに省電力になりますが、戻るときに少し遅れるので、低遅延が大事なサーバでは切ることもあります。"),
        d("int-4", "D3hotは、電源は来ているがデバイスの機能は止まっている状態です。コンフィグ空間にはアクセスできるので、ソフトウェアが書き込んでD0に戻せます。D3coldは主電源まで切れているので、コンフィグ空間にもアクセスできません。"),
        d("int-5", "PCIeには割り込み専用の線がないので、旧PCIの割り込み線（INTA〜INTD）の状態を、**Assert_INTx / Deassert_INTx**メッセージで伝えます。古いソフトウェアとの互換のための仕組みで、新しいデバイスはMSI/MSI-Xを使います。"),
        d("int-6", "MSI-Xのテーブル（ベクタごとのアドレス・データ・マスク）とPBA（保留中のビット）は、デバイスのBARが指すメモリ空間に置かれます。コンフィグ空間のMSI-X Capabilityには、それがどのBARのどのオフセットにあるかだけが書かれています。"),
        d("int-7", "L1.2では、受信器の検出回路やリファレンスクロックまで止めて、待機電力をさらに減らします。**CLKREQ#**信号を使って、どちらかがクロックを必要としていることを伝え、L1.2から戻ります。ノートPCのバッテリーの持ちに大きく効きます。"),
        d("int-8", "L0sはNon-Flit Modeだけの省電力状態で、Flit Modeでは使えません。Flit Modeでは、リンクを止めずに使うレーン数を減らす**L0p**で省電力にします。L1やL1 PM SubstatesはFlit Modeでも使えます。"),
        d("int-9", "**LTR**（Latency Tolerance Reporting）は、デバイスが「このくらいなら応答が遅れても大丈夫」という時間をシステムに伝える仕組みです。プラットフォームはこの値を見て、どこまで深い省電力状態に入ってよいかを決めます。"),
        d("int-10", "MSIは最大32ベクタです。ベクタ数は2のべき乗（1、2、4、8、16、32）で、データの下位ビットを変えて区別します。ベクタごとに別のアドレスを設定できないので、細かく振り分けたいときはMSI-Xを使います。"),
        d("int-11", "MSI-Xは、ベクタごとに**アドレス・データ・マスク**を別々に設定できます。そのため、キューごとに違うCPUへ割り込みを送るなど、柔軟な使い方ができます。MSIは、すべてのベクタで同じアドレスを使います。"),
        d("int-12", "D3coldは主電源（Vcc）が切れた状態です。戻るにはリセットと初期化のやり直しが必要です。補助電源（Vaux）があれば、PMEでシステムを起こすことはできます。"),
        d("int-13", "ASPMが制御するのは**L0sとL1**です。L2やL3は、ソフトウェアがシステムやデバイスの電源を切るときに使う状態です。D0/D3はリンクではなく、デバイスの電源状態です。"),
        d("int-14", "L1 PM Substatesは、L1をさらに**L1.1**と**L1.2**に分けたものです。L1.2が最も深く、受信器の検出回路も止めます。そのぶん戻るのに時間がかかるので、LTRの値を見て入るかどうかを決めます。"),
        d("int-15", "**PME**（Power Management Event）は、省電力状態のデバイスが「起こしてほしい」とシステムに伝える仕組みです。リンクが動いていればPM_PMEメッセージを送り、L2のようにリンクが止まっていればWAKE#信号などで知らせます。"),

        // 12. 順序規則とエラー処理
        d("ord-1", "Read RequestがPosted Writeを追い越さないので、**書いたあとに読めば、書き込みが反映された値が返ります**（write flush）。ドライバが「書き込みが確実に届いたか」を確かめるのに、この性質を使います。"),
        d("ord-2", "Posted WriteはNon-Posted Requestを**追い越せなければなりません**。そうしないと、Readの応答を待つ間にWriteが詰まり、そのWriteが進まないとReadも進まない、というデッドロックが起きることがあります。"),
        d("ord-3", "Completion Timeoutは、Readなどの応答が決められた時間内に返ってこなかったエラーです。既定ではUncorrectable **Non-Fatal**で、そのトランザクションだけが失敗し、リンク自体は使い続けられます。"),
        d("ord-4", "Replay Timer Timeoutは、ACKが返ってこなくて再送したことを示します。再送でハードウェアが自動的に回復できるので、**Correctable**です。たくさん起きるときは、信号品質の問題を疑います。"),
        d("ord-5", "**DPC**（Downstream Port Containment）は、重大なエラーが起きたときに、ダウンストリームポートがリンクを自動で止めて、エラーが広がるのを防ぐ機能です。そのあと、ソフトウェアがリンクを復旧させます。"),
        d("ord-6", "順序規則は、**同じTC（Traffic Class）**のTLPの間だけで適用されます。TCが違えば別のVC（仮想チャネル）を通ることもあり、互いの順序は保証されません。"),
        d("ord-7", "Relaxed Ordering（RO）が1のPosted Requestは、ほかのPosted Requestを追い越してよいことになっています。順番が関係ないデータ（大きなバッファの書き込みなど）で使うと、性能が上がることがあります。"),
        d("ord-8", "Non-Posted Request同士は、追い越しが許されています。たとえば2つのReadは、どちらが先に処理されてもかまいません。Readの結果（Completion）は、Requester IDとTagで対応付けられます。"),
        d("ord-9", "Malformed TLPは、ヘッダの形がおかしいTLPです。リンクの相手が仕様どおりに動いていない可能性があるので、既定では**Uncorrectable Fatal**です。AERがあれば、重大度を設定で変えられます。"),
        d("ord-10", "AERは、エラーが起きたときに原因になったTLPの**ヘッダ**をHeader Logに記録します。どのアドレスへの、どんなリクエストで起きたかがわかるので、原因の特定に役立ちます。"),
        d("ord-11", "Relaxed Orderingが指定されていないPosted Write同士は、追い越してはいけません。「データを書いてからフラグを書く」という順番が保たれないと、フラグを見た側が古いデータを読んでしまうからです。"),
        d("ord-12", "**Producer/Consumerモデル**を守るためです。デバイスがデータを書いて（Posted Write）、CPUがフラグを読む（Completionで返る）とき、Completionが先にデータを追い越すと、CPUは古いデータを読んでしまいます。"),
        d("ord-13", "**ID-Based Ordering（IDO）**は、送信元（Requester ID）が違うTLP同士なら、依存関係がないとみなして追い越しを許す属性です。別々のデバイスやFunctionからのトラフィックが、お互いを待たずに流れるので、性能が上がります。"),
        d("ord-14", "Bad TLPは、LCRCが合わないなど、データリンク層で見つかる誤りです。再送で自動的に回復できるので**Correctable**です。Completion TimeoutやUnsupported RequestはNon-Fatal、Malformed TLPはFatalが既定です。"),
        d("ord-15", "Unsupported Request（UR）は、応答側がそのリクエストを処理できないときに返します。対応していない種類のリクエストや、どの宛先にも当たらないアドレスへのアクセスなどが例です。Non-PostedならCompletion StatusのURで応答します。"),
        d("ord-16", "エラーを見つけたデバイスは、ERR_COR / ERR_NONFATAL / ERR_FATALのメッセージを上流に送ります。メッセージはスイッチを通って**Root Port**に届き、Root Portが割り込みなどでOSに知らせます。"),
    ]
}
