package edu.berkeley.cs.amplab.carat.android;

import java.util.List;

import edu.berkeley.cs.amplab.carat.android.suggestions.ProcessInfoAdapter;
import edu.berkeley.cs.amplab.carat.thrift.Reports;
import android.app.Activity;
import android.app.ActivityManager.RunningAppProcessInfo;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.Window;
import android.webkit.WebView;
import android.widget.AdapterView;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.ProgressBar;
import android.widget.Toast;
import android.widget.ViewFlipper;
import android.widget.AdapterView.OnItemClickListener;

/**
 * 
 * @author Eemil Lagerspetz
 * 
 */
public class CaratMyDeviceActivity extends Activity {

	private CaratApplication app = null;
	private ViewFlipper vf = null;
	private int baseViewIndex = 0;

	/** Called when the activity is first created. */
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.mydevice);
		app = (CaratApplication) this.getApplication();

		vf = (ViewFlipper) findViewById(R.id.viewFlipper);
		View baseView = findViewById(R.id.scrollView1);
		baseView.setOnTouchListener(
				SwipeListener.instance);
		baseViewIndex = vf.indexOfChild(baseView);
		initJscoreView();
		initProcessListView();
	}

	private void initJscoreView() {
		WebView webview = (WebView) findViewById(R.id.jscoreView);
		// Fixes the white flash when showing the page for the first time.
		if (getString(R.string.blackBackground).equals("true"))
			webview.setBackgroundColor(0);
		/*
		 * 
		 * 
		 * webview.getSettings().setJavaScriptEnabled(true);
		 */
		/*
		 * To display the amplab_logo, we need to have it stored in assets as
		 * well. If we don't want to do that, the loadConvoluted method below
		 * avoids it.
		 */
		webview.loadUrl("file:///android_asset/jscoreinfo.html");
		webview.setOnTouchListener(new FlipperBackListener(vf, vf
				.indexOfChild(findViewById(R.id.scrollView1))));
	}

	private void initProcessListView() {
		final ListView lv = (ListView) findViewById(R.id.processList);
		lv.setCacheColorHint(0);
		// Ignore clicks here.
/*
		lv.setOnItemClickListener(new OnItemClickListener() {
			@Override
			public void onItemClick(AdapterView<?> a, View v, int position,
					long id) {
				Object o = lv.getItemAtPosition(position);
				RunningAppProcessInfo fullObject = (RunningAppProcessInfo) o;
				Toast.makeText(CaratMyDeviceActivity.this,
						"You have chosen: " + " " + fullObject.processName,
						Toast.LENGTH_LONG).show();
			}
		});*/
		lv.setOnTouchListener(new FlipperBackListener(vf, vf
				.indexOfChild(findViewById(R.id.scrollView1))));
	}

	/**
	 * (non-Javadoc)
	 * 
	 * @see android.app.Activity#onResume()
	 */
	@Override
	protected void onResume() {
		new Thread() {
			public void run() {
				app.c.refreshReports();
			}
		}.start();

		setModelAndVersion();
		setMemory();
		setReportData();
		super.onResume();
	}

	/**
	 * Called when Jscore additional info button is clicked.
	 * 
	 * @param v
	 *            The source of the click.
	 */
	public void viewJscoreInfo(View v) {
		View target = findViewById(R.id.jscoreView);
		vf.setOutAnimation(CaratMainActivity.outtoLeft);
		vf.setInAnimation(CaratMainActivity.inFromRight);
		vf.setDisplayedChild(vf.indexOfChild(target));
	}

	/**
	 * Called when View Process List is clicked.
	 * 
	 * @param v
	 *            The source of the click.
	 */
	public void viewProcessList(View v) {
		// prepare content:
		ListView lv = (ListView) findViewById(R.id.processList);
		List<RunningAppProcessInfo> searchResults = SamplingLibrary.getRunningProcessInfo(getApplicationContext());
		lv.setAdapter(new ProcessInfoAdapter(this, searchResults, app));
		// switch views:
		View target = findViewById(R.id.processList);
		vf.setOutAnimation(CaratMainActivity.outtoLeft);
		vf.setInAnimation(CaratMainActivity.inFromRight);
		vf.setDisplayedChild(vf.indexOfChild(target));
	}

	/*
	 * (non-Javadoc)
	 * 
	 * @see android.app.Activity#onActivityResult(int, int,
	 * android.content.Intent)
	 */
	@Override
	protected void onActivityResult(int requestCode, int resultCode, Intent data) {
		// TODO Auto-generated method stub
		findViewById(R.id.scrollView1).startAnimation(
				CaratMainActivity.inFromLeft);
		super.onActivityResult(requestCode, resultCode, data);
	}

	private void setModelAndVersion() {
		// Device model
		String model = SamplingLibrary.getModel();

		// Android version
		String version = SamplingLibrary.getOsVersion();

		Window win = this.getWindow();
		// The info icon needs to change from dark to light.
		TextView mText = (TextView) win.findViewById(R.id.dev_value);
		mText.setText(model);
		mText = (TextView) win.findViewById(R.id.os_ver_value);
		mText.setText(version);
	}

	private void setMemory() {
		Window win = this.getWindow();
		// Set memory values to the progress bar.
		ProgressBar mText = (ProgressBar) win.findViewById(R.id.progressBar1);
		mText.setMax(app.totalAndUsed[0]+app.totalAndUsed[1]);
		mText.setProgress(app.totalAndUsed[0]);
		mText = (ProgressBar) win.findViewById(R.id.progressBar2);

		if (app.totalAndUsed.length > 2) {
			mText.setMax(app.totalAndUsed[2]+app.totalAndUsed[3]);
			mText.setProgress(app.totalAndUsed[2]);
		}

		/* CPU usage */
		mText = (ProgressBar) win.findViewById(R.id.cpubar);
		mText.setMax(100);
		mText.setProgress(app.cpu);
	}

	private void setReportData() {
		final Reports r = app.s.getReports();
		Log.i("CaratHomeScreen", "Got reports: " + r);
		long l = System.currentTimeMillis() - app.s.getFreshness();
		final long min = l / 60000;
		final long sec = (l - min * 60000) / 1000;
		double bl = 0;
		int jscore = 0;
		if (r != null) {
			bl = 100 / r.getModel().expectedValue;
			jscore = ((int) (r.getJScore() * 100));
		}
		int blh = (int) (bl / 3600);
		bl -= blh * 3600;
		int blmin = (int) (bl / 60);
		int bls = (int) (bl - blmin * 60);
		final String blS = blh + "h " + blmin + "m " + bls + "s";
		setText(R.id.jscore_value, jscore + "");
		setText(R.id.updated, "(Updated " + min + "m " + sec + "s ago)");
		setText(R.id.batterylife_value, blS);
	}

	private void setText(int viewId, String text) {
		Window win = this.getWindow();
		TextView t = (TextView) win.findViewById(viewId);
		t.setText(text);
	}

	public void onBackPressed() {
		if (vf.getDisplayedChild() != baseViewIndex) {
			vf.setOutAnimation(CaratMainActivity.outtoRight);
			vf.setInAnimation(CaratMainActivity.inFromLeft);
			vf.setDisplayedChild(baseViewIndex);
		} else
			finish();
	}
}
