package com.example.alfred.ncu_csie_ce6144_hw0413;

import android.os.Handler;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.OutputStreamWriter;
import java.io.InputStreamReader;
import java.net.Socket;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class MainActivity extends AppCompatActivity
{

    private Button m_btn_connect, m_btn_disConnect, m_btn_send;
    private Thread m_threadSocket, m_threadReceive, m_threadSend;
    private Socket m_socket;
    private TextView m_txtView;
    private BufferedWriter m_bufferWeite;
    private BufferedReader m_bufferRead;
    private String m_strTmp, m_strTmp2;
    private EditText m_edTxt_IP, m_edTxt_Msg;
    private Handler m_handler;

    private static final Pattern IP_ADDRESS
            = Pattern.compile(
            "((25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9])\\.(25[0-5]|2[0-4]"
                    + "[0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\\.(25[0-5]|2[0-4][0-9]|[0-1]"
                    + "[0-9]{2}|[1-9][0-9]|[1-9]|0)\\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}"
                    + "|[1-9][0-9]|[0-9]))");

    @Override
    protected void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        objectInit();

        xmlObjectsLink();
        buttonListenerInit();
    }

    private void objectInit()
    {
        m_threadSocket = null;
        m_threadReceive = null;
        m_threadSend = null;
        m_handler = new Handler();
    }

    private void xmlObjectsLink()
    {
        m_btn_connect = findViewById(R.id.btn_connect);
        m_btn_disConnect = findViewById(R.id.btn_disConnect);
        m_btn_send = findViewById(R.id.btn_send);
        m_txtView = findViewById(R.id.txtView);

        m_edTxt_IP = findViewById(R.id.eTxt_IP);
        m_edTxt_Msg = findViewById(R.id.eTxt_MSG);
    }

    private void buttonListenerInit()
    {
        m_btn_connect.setOnClickListener(onConnectButtonClick);
        m_btn_disConnect.setOnClickListener(onDisConnectButtonClick);
        m_btn_send.setOnClickListener(onSendButtonClick);
    }

    private boolean isValidIPAddr(String msg)
    {
        Matcher matcher = IP_ADDRESS.matcher(msg);
        return matcher.matches();
    }

    @Override
    protected void onDestroy()
    {
        super.onDestroy();
        try
        {
            m_bufferWeite.flush();
            m_bufferWeite.close();
            m_bufferWeite.close();
            m_socket.close();
        }
        catch (Exception e)
        {
            e.printStackTrace();
        }
    }

    Button.OnClickListener onConnectButtonClick = new View.OnClickListener()
    {
        @Override
        public void onClick(View v)
        {
            // 先檢查 IP 合法與否.
            if ( isValidIPAddr(m_edTxt_IP.getText().toString()) )
            {
                if ( m_socket == null )
                {
                    if ( m_threadSocket == null )
                    {
                        m_threadSocket = new Thread(threadConnection_Run);
                        m_threadSocket.start();
                    }
                }
            }
            else
            {
                m_txtView.append("please input valid IP address !\n");
            }
        }
    };

    Button.OnClickListener onDisConnectButtonClick = new View.OnClickListener()
    {
        @Override
        public void onClick(View v)
        {
            try
            {
                m_socket.close();
                m_threadSocket = null;
                m_socket = null;
                m_txtView.append("Disconnected !\n");
            }
            catch (Exception e)
            {
                e.printStackTrace();
            }
        }
    };

    Button.OnClickListener onSendButtonClick = new View.OnClickListener()
    {
        @Override
        public void onClick(View v)
        {
            // 空字串不給傳送，避免 server 端誤判 Client 斷線.
            if ( false == m_edTxt_Msg.getText().toString().equals("") )
            {
                if ( m_threadSend == null )
                {
                    m_threadSend = new Thread(threadSend_Run);
                    m_threadSend.start();
                }
                m_strTmp2 = m_edTxt_Msg.getText().toString();
                m_edTxt_Msg.setText("");
            }
            else
            {
                m_txtView.append("please input valid IP address !\n");
            }
        }
    };

    private Runnable threadConnection_Run = new Runnable()
    {
        @Override
        public void run()
        {
            try
            {
                String ServerIP = m_edTxt_IP.getText().toString();
                int socket_Port = 5050;

                m_socket = new Socket(ServerIP, socket_Port);

                m_bufferRead = new BufferedReader(new InputStreamReader(m_socket.getInputStream()));
                m_bufferWeite = new BufferedWriter(new OutputStreamWriter(m_socket.getOutputStream()));

                if ( m_socket.isConnected() )
                {
                    m_txtView.append("Did Connect to" + ServerIP + ":" + socket_Port + "\n");
                }
                else
                {
                    m_txtView.append("Connection Fail\n");
                    m_socket.close();
                    m_socket = null;
                    m_threadSocket = null;
                }

                if ( m_threadReceive == null )
                {
                    m_threadReceive = new Thread(threadReceive_Run);
                    m_threadReceive.start();
                }
            }
            catch(Exception e)
            {
                e.printStackTrace();
            }
        }
    };

    private Runnable threadReceive_Run = new Runnable()
    {
        @Override
        public void run()
        {
            try
            {
                while ( m_socket.isConnected() )
                {
                    m_strTmp = m_bufferRead.readLine();

                    if ( m_strTmp != null )
                    {
                        m_handler.post(handlerUpdateData);
                    }
                }
            }
            catch (Exception e)
            {
                e.printStackTrace();
            }
        }
    };

    private Runnable threadSend_Run = new Runnable()
    {
        public void run()
        {
            try
            {
                while ( m_socket.isConnected() )
                {
                    if ( m_strTmp2 != null )
                    {
                        m_bufferWeite.write(m_strTmp2+"\n");
                        m_bufferWeite.flush();
                        m_strTmp2 = null;
                    }
                }
            }
            catch (Exception e)
            {
                e.printStackTrace();
            }
        }
    };

    private Runnable handlerUpdateData = new Runnable()
    {
        public void run()
        {
            try
            {
                if ( m_strTmp != null )
                {
                    m_txtView.append("received data from server: " + m_strTmp + "\n");
                    m_strTmp = null;
                }
            }
            catch (Exception e)
            {
                e.printStackTrace();
            }
        }
    };
}
